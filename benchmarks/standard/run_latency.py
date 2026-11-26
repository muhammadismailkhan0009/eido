#!/usr/bin/env python3
"""Independent matched pointer/index latency and small allocation workloads."""
import argparse
import json
import os
from pathlib import Path
import random
import re
import shutil
import statistics
import subprocess
from run import ROOT, HERE, BUILD, UP, run, output, sha, prepare_native

SIZES = [4096, 32768, 262144, 1048576, 8388608, 67108864]
SMALL_SIZES = [8, 32, 128]
SMALL_COUNT = 200000
LM_VERSION = "3.0-a9+debian.1-6build3"
CACHE_REVISION = "ec3e85908f4cec7e51012a37e2a2c5c0a8680711"

def build():
    BUILD.mkdir(parents=True,exist_ok=True)
    UP.mkdir(parents=True,exist_ok=True)
    run("nim","c","-d:release","--hints:off","--path:compiler/src",
        f"-o:{BUILD/'latency-compiler'}","tools/cli/src/eido.nim")
    support=BUILD/"latency-native"
    prepare_native(support)
    env=dict(os.environ,EIDO_NATIVE_NIM_PATH=str(support))
    for name in ["latency","small-alloc"]:
        run(BUILD/"latency-compiler","build",HERE/name/"module.yaml","--memory=none",
            "-o",BUILD/f"{name}-eido",env=env)
        run("gcc","-O3","-Wall","-Wextra",HERE/name/"Reference.c","-o",BUILD/f"{name}-c")
    source=UP/"cache-scratch.cpp"
    run("curl","-fLsS","--max-time","30",
        f"https://raw.githubusercontent.com/daanx/mimalloc-bench/{CACHE_REVISION}/bench/cache-scratch/cache-scratch.cpp",
        "-o",source)
    assert sha(source)=="5014cd7c0c7b57ceb99c329078427b93c2c65bda0aee33f4ed4e93dada868a78", "upstream source changed"
    run("g++","-O3","-pthread",source,"-o",BUILD/"cache-scratch-upstream")

def lmbench():
    folder=UP/"debs"
    folder.mkdir(exist_ok=True)
    matches=list(folder.glob("lmbench_*.deb"))
    if not matches:
        subprocess.run(["apt","download",f"lmbench={LM_VERSION}"],cwd=folder,check=True)
        matches=list(folder.glob("lmbench_*.deb"))
    assert len(matches)==1
    deb=matches[0]
    version=output("dpkg-deb","-f",deb,"Version").strip()
    assert version==LM_VERSION,version
    run("dpkg-deb","-x",deb,folder/"lmbench")
    exe=next((folder/"lmbench").rglob("lat_mem_rd"))
    # Unmodified distro binary. The full upstream sweep differs from our
    # matched fixed-count trials, so report it as context, not a speed ratio.
    p=run(exe,"-P","1","-N","3","64","64",capture_output=True,text=True,timeout=150)
    text=p.stdout+"\n"+p.stderr
    rows=[]
    for l in text.splitlines():
        m=re.fullmatch(r"\s*(\d+\.\d+)\s+(\d+\.\d+)\s*",l)
        if m: rows.append([float(m[1]),float(m[2])])
    assert len(rows)>10,text
    return {"package_version":version,"package_sha256":sha(deb),"binary_sha256":sha(exe),"raw":text,"MiB_ns":rows}

def latency(size,mode,variant):
    stride=8 # eight 64-bit slots = 64 bytes
    n=size//64
    command=[BUILD/("latency-eido" if variant=="eido" else "latency-c"),n,stride,mode]
    if variant!="eido":command.append(int(variant=="c-pointer"))
    p=run("/usr/bin/time","-f","%M",*command,capture_output=True,text=True,timeout=60)
    lines=p.stdout.splitlines()
    assert len(lines)==8 and lines[-1]=="VALID",p.stdout
    ns=[int(x) for x in lines[:-1]]
    steps=(4000000//n+1)*n
    assert min(ns)>0
    return {"steps":steps,"trial_ns":ns,"median_ns_per_load":statistics.median(ns)/steps,
            "min_ns_per_load":min(ns)/steps,"max_ns_per_load":max(ns)/steps,"rss_KiB":int(p.stderr.strip())}

def small(size,variant):
    p=run("/usr/bin/time","-f","%M",BUILD/f"small-alloc-{variant}",size,SMALL_COUNT,
          capture_output=True,text=True,timeout=30)
    lines=p.stdout.splitlines()
    assert len(lines)==3 and lines[-1]=="VALID"
    assert int(lines[1])==SMALL_COUNT*size*(size-1)//2
    elapsed=int(lines[0]);assert elapsed>0
    return {"ns":elapsed,"checksum":int(lines[1]),"ns_per_cycle":elapsed/SMALL_COUNT,
            "rss_KiB":int(p.stderr.strip())}

def audit():
    # Check the actual binaries, not only the source. The upstream cache-scratch
    # worker loses its new[]/delete[] calls at -O3 with GCC 14.
    dis=output("objdump","-d","-C",BUILD/"cache-scratch-upstream")
    worker=dis.split("<worker>:",1)[1].split("\n\n",1)[0]
    (BUILD/"cache-scratch-worker.asm").write_text(worker)
    actual=output("objdump","-d","-C",BUILD/"small-alloc-c")
    assert "call" in actual and "calloc@plt" in actual and "free@plt" in actual
    evidence={"cache_scratch_worker_calls_new_array": "operator new[]" in worker,
              "cache_scratch_worker_calls_delete_array": "operator delete[]" in worker,
              "matched_c_retains_calloc_free":True,
              "cache_scratch_revision":CACHE_REVISION,
              "cache_scratch_source_sha256":sha(UP/"cache-scratch.cpp")}
    for name in ["latency","small-alloc"]:
        binary=BUILD/f"{name}-eido"
        syms=output("nm","-C",binary)
        assert all(x in syms for x in ["eidoStorageAllocateRaw","eidoStorageRelease"])
        if not all(x in syms for x in ["eidoStorageRead","eidoStorageWrite"]):
            asm=output("objdump","-d","-C",binary)
            assert "imul" in asm and "raiseExceptionEx" in asm
            (BUILD/f"{name}-native.asm").write_text(asm)
        evidence[name+"_binary_sha256"]=sha(binary)
    # Independent physical audit of a 4096-cycle workload. Native allocation
    # trace is outside timing; instrument only copied SDK provider.
    source=BUILD/"latency-native"
    if not source.exists():source=BUILD/"native" # initial local build
    support=BUILD/"small-audit-native"
    shutil.copytree(source,support,dirs_exist_ok=True)
    p=support/"eido_storage.nim";s=p.read_text()
    a=next(x for x in ("  result.data = cast[ptr UncheckedArray[int8]](alloc0(byteCount))", "  result.data = cast[ptr UncheckedArray[int8]](systemAllocate(1, csize_t(byteCount)))") if s.count(x)==1)
    b=next(x for x in ("    dealloc(base)", "    systemRelease(base)") if s.count(x)==1)
    assert s.count(a)==s.count(b)==1
    s=s.replace(a,a+'\n  if byteCount == 32: stderr.writeLine("A " & $cast[uint](result.data))')
    s=s.replace(b,'    stderr.writeLine("F " & $cast[uint](base))\n'+b)
    p.write_text("import std/syncio\n"+s)
    compiler=BUILD/"latency-compiler"
    if not compiler.exists():compiler=ROOT/"eido"
    run(compiler,"build",HERE/"small-alloc/module.yaml","--memory=none","-o",BUILD/"small-audit",
        env=dict(os.environ,EIDO_NATIVE_NIM_PATH=str(support)))
    p=run(BUILD/"small-audit",32,4096,capture_output=True,text=True)
    assert p.stdout.splitlines()[-1]=="VALID"
    active=set();a=f=0
    for line in p.stderr.splitlines():
        kind,ptr=line.split()
        if kind=="A":
            assert not active
            active.add(ptr);a+=1
        elif kind=="F" and ptr in active:
            active.remove(ptr);f+=1
    assert a==f==4096 and not active,(a,f)
    evidence.update({"audited_small_allocations":a,"audited_small_frees":f})
    return evidence

def main():
    p=argparse.ArgumentParser()
    p.add_argument("--skip-build",action="store_true")
    p.add_argument("--skip-lmbench",action="store_true")
    p.add_argument("--rounds",type=int,default=3)
    p.add_argument("--small-rounds",type=int,default=5)
    args=p.parse_args()
    assert args.rounds>0 and args.small_rounds>0
    if not args.skip_build:build()
    ev=audit()
    cpu=min(os.sched_getaffinity(0));os.sched_setaffinity(0,{cpu})
    rng=random.Random(42)
    cases=[(size,mode,v) for size in SIZES for mode in (0,1) for v in ("c-pointer","c-index","eido")]
    rows=[]
    # Seven internal trials per process; repeat each case in independent
    # processes when rounds > 1; randomize case order.
    for r in range(args.rounds):
        rng.shuffle(cases)
        for size,mode,v in cases:
            row=dict(latency(size,mode,v),size_bytes=size,pattern="random" if mode else "fixed",variant=v,round=r)
            rows.append(row)
            print("latency",r,size,row["pattern"],v,round(row["median_ns_per_load"],3),flush=True)
    alloc=[]
    cases=[(size,v) for size in SMALL_SIZES for v in ("c","eido")]
    for r in range(args.small_rounds+1):
        rng.shuffle(cases)
        for size,v in cases:
            row=dict(small(size,v),size_bytes=size,variant=v,round=r)
            if r:alloc.append(row)
            print("small",r,size,v,round(row["ns_per_cycle"],3),flush=True)
    result={"head":output("git","rev-parse","HEAD").strip(),"dirty":bool(output("git","status","--porcelain").strip()),
            "cpu":cpu,"cpu_model":next(s.split(":",1)[1].strip() for s in Path("/proc/cpuinfo").read_text().splitlines() if s.startswith("model name")),
            "gcc":output("gcc","--version").splitlines()[0],"nim":output("nim","--version").splitlines()[0],
            "rounds":args.rounds,"small_rounds":args.small_rounds,"stride_bytes":64,"small_count":SMALL_COUNT,"audit":ev,
            "binaries":{name:sha(BUILD/name) for name in ["latency-c","latency-eido","small-alloc-c","small-alloc-eido"]},
            "latency":rows,"small_alloc":alloc}
    # Persist matched results even if the optional external reference is unavailable.
    path=BUILD/"latency-results.json"
    path.write_text(json.dumps(result,indent=2)+"\n")
    if not args.skip_lmbench:
        try:result["lmbench"]=lmbench()
        except (subprocess.SubprocessError,StopIteration,AssertionError) as exc:result["lmbench_error"]=str(exc)
        path.write_text(json.dumps(result,indent=2)+"\n")
    for size in SIZES:
        for mode in ("fixed","random"):
            values={v:round(statistics.median(x["median_ns_per_load"] for x in rows if x["size_bytes"]==size and x["pattern"]==mode and x["variant"]==v),3) for v in ("c-pointer","c-index","eido")}
            print("SUMMARY",size,mode,values)
    for size in SMALL_SIZES:
        print("SMALL SUMMARY",size,{v:round(statistics.median(x["ns_per_cycle"] for x in alloc if x["size_bytes"]==size and x["variant"]==v),3) for v in ("c","eido")})
if __name__=="__main__":main()
