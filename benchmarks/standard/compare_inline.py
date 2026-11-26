"""Paired comparison of native SDK changes, with unchanged compiler and workloads."""
import argparse
import json
import os
from pathlib import Path
import random
import shutil
import statistics
import subprocess
import sys

from run import ROOT, HERE, BUILD, run, sha, output, NAMES, BYTES, prepare_native

BASE = ROOT / "benchmarks/build/inline-comparison"
SDK = ROOT / "stdlib/native/nim"
BENCH = ROOT / "benchmarks"

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--repeats", type=int, default=3)
    p.add_argument("--experiment", choices=("inline","stride","byte-inline","allocator"), default="inline")
    p.add_argument("--baseline", type=Path, required=True,
                   help="Original native provider before the selected experiment")
    a = p.parse_args()
    global BASE
    BASE = ROOT / f"benchmarks/build/{a.experiment}-comparison"
    assert a.repeats >= 3
    BASE.mkdir(parents=True, exist_ok=True)
    old = a.baseline.read_text()
    provider = "eido_native_bytes.nim" if a.experiment == "byte-inline" else "eido_storage.nim"
    new = ((HERE/"support" if a.experiment == "byte-inline" else SDK)/provider).read_text()
    if a.experiment == "inline":
        assert old == new.replace(" {.inline.}", ""), "comparison must differ only in pragmas"
    elif a.experiment == "byte-inline":
        expected = old
        for signature in ("proc eido_native_method_Bytes_unsigned*(value: int8): int64",
                          "proc eido_native_method_Bytes_fromUnsigned*(value: int64): int8"):
            assert expected.count(signature+" =")==1
            expected=expected.replace(signature+" =",signature+" {.inline.} =")
        assert expected==new, "comparison must differ only in two byte conversion pragmas"
    elif a.experiment == "allocator":
        declaration = ('# Hosted physical backing only; all ownership and alignment remain unchanged.\n'
                       'proc systemAllocate(count, size: csize_t): pointer\n'
                       '  {.importc: "calloc", header: "<stdlib.h>".}\n'
                       'proc systemRelease(address: pointer)\n'
                       '  {.importc: "free", header: "<stdlib.h>".}\n\n')
        expected=old.replace("type\n  EidoStorage*", declaration+"type\n  EidoStorage*").replace("alloc0(byteCount)","systemAllocate(1, csize_t(byteCount))").replace("    dealloc(base)","    systemRelease(base)")
        assert expected==new, "comparison must differ only in native allocation pair"
    else:
        original = "  cast[uint](storage.data) + uint(index) * uint(storage.strideBytes)\n"
        replacement = ("  # A typed view may retain a wider raw stride. Only use a constant\n"
                       "  # scale when the descriptor's actual stride matches the type width.\n"
                       "  if storage.strideBytes == int64(sizeof(T)):\n"
                       "    cast[uint](storage.data) + uint(index) * uint(sizeof(T))\n"
                       "  else:\n"
                       "    cast[uint](storage.data) + uint(index) * uint(storage.strideBytes)\n")
        assert old.count(original)==1 and old.replace(original,replacement)==new, "comparison must differ only in stride fast path"
    compiler=BASE/"eido"
    run("nim","c","-d:release","--hints:off","--path:compiler/src",f"-o:{compiler}","tools/cli/src/eido.nim")
    cases=[]
    for version in ("before","after"):
        folder=BASE/version
        native=folder/"native"
        prepare_native(native)
        (native/provider).write_text(old if version=="before" else new)
        env=dict(os.environ,EIDO_NATIVE_NIM_PATH=str(native))
        for name,manifest in [("stream",HERE/"stream/module.yaml"),("latency",HERE/"latency/module.yaml"),("small",HERE/"small-alloc/module.yaml"),("malloc",HERE/"malloc-large/module.yaml"),("storage",BENCH/"storage/module.yaml")]:
            run(compiler,"build",manifest,"--memory=none","-o",folder/name,env=env)
        for layout in ("default","compact","wide"):
            project=folder/"layouts"/layout
            project.mkdir(parents=True,exist_ok=True)
            shutil.copytree(BENCH/"inline-policy",project/"inline-policy",dirs_exist_ok=True)
            files=["Main.eido","Row.eido","Compact.eido","Wide.eido","VerifyLayout.eido"]
            for file in files:shutil.copyfile(BENCH/"layouts"/file,project/file)
            if layout!="default":
                (project/"Selection.eido").write_text(f'LayoutPolicy.select("Row", "{layout.title()}");\n')
                files.append("Selection.eido")
            (project/"module.yaml").write_text("module: layout_bench\nsources:\n"+"".join("  - "+f+"\n" for f in files)+"children:\n  inline_policy: { path: inline-policy }\ndependencies: []\nexports: []\nprovides: {}\nadopts: []\n")
            run(compiler,"build",project/"module.yaml","--memory=layout_bench.inline_policy","-o",folder/f"layout-{layout}",env=env)
            assert output(folder/f"layout-{layout}","size").strip()==str({"default":32,"compact":24,"wide":64}[layout])
            p=subprocess.run([str(folder/f"layout-{layout}"),"verify-reject"],capture_output=True)
            assert p.returncode==91,p.returncode
        for name in ("stream","latency","small","malloc","storage","layout-default","layout-compact","layout-wide"):
            (folder/f"{name}.asm").write_text(output("objdump","-d","-C",folder/name))
        cases.append(folder)
    # Same generated Eido code for both variants; only the native provider differs.
    for name in ("stream","latency","small","malloc","storage","layout-default","layout-compact","layout-wide"):
        filename=name.replace("-","_")+"_generated.nim"
        assert (cases[0]/filename).read_bytes()==(cases[1]/filename).read_bytes(),name
    # Standalone trace generation is not measured.
    trace=BASE/"trace.txt"
    run("g++","-O3",HERE/"malloc-large/Trace.cpp","-o",BASE/"trace-gen")
    trace.write_text(output(BASE/"trace-gen"))
    import time
    os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
    cpu=min(os.sched_getaffinity(0))
    def measure(folder,name,args):
        start=time.perf_counter_ns()
        p=run("/usr/bin/time","-f","%M",folder/name,*args,capture_output=True,text=True,timeout=60)
        wall=time.perf_counter_ns()-start
        lines=p.stdout.splitlines()
        values={}
        if name=="stream":
            assert lines[0]=="VALID" and len(lines)==41
            ns=list(map(int,lines[1:]));assert min(ns)>0
            values={label:BYTES[i]*1000/min(ns[4+i::4]) for i,label in enumerate(NAMES)}
        elif name=="latency":
            assert lines[-1]=="VALID" and len(lines)==8
            n=int(args[0]);steps=(4000000//n+1)*n
            values={"ns_per_load":statistics.median(map(int,lines[:-1]))/steps}
        elif name=="small":
            assert lines[-1]=="VALID" and int(lines[1])==int(args[1])*int(args[0])*(int(args[0])-1)//2
            values={"ns_per_cycle":int(lines[0])/int(args[1])}
        elif name=="malloc":
            values={"loop_ms":int(lines[0])/1e6,"wall_ms":wall/1e6}
        else:
            n=2_000_000
            expected=12*n*(n+2) if name.startswith("layout") else (12*n*(n+1)//2 if args[0] in ("typed","raw") else 1_000_000*1_000_001//2)
            assert int(lines[0])==expected,(name,args,lines)
            values={"wall_ms":wall/1e6}
        return {"values":values,"rss_KiB":int(p.stderr.strip())}
    specs=[("stream",[]),("malloc",[trace])]
    specs += [("latency",[n,8,r]) for n in (64,512,4096,16384,131072,1048576) for r in (0,1)]
    specs += [("small",[s,200000]) for s in (8,32,128)]
    specs += [("storage",[m]) for m in ("typed","raw","churn","reuse","placement")]
    specs += [(f"layout-{l}",["scan"]) for l in ("default","compact","wide")]
    # Paired randomized order. One discarded warmup round for all cases.
    samples={}
    rng=random.Random(42)
    for r in range(a.repeats+1):
        rng.shuffle(specs)
        for name,args in specs:
            key=name+":"+",".join(str(x) if not isinstance(x,Path) else x.name for x in args)
            pair=list(cases);rng.shuffle(pair)
            for folder in pair:
                sample=measure(folder,name,args)
                if r:samples.setdefault(key,{}).setdefault(folder.name,[]).append(sample)
                print(r,key,folder.name,sample,flush=True)
    summary={}
    for key,versions in samples.items():
        summary[key]={v:{k:statistics.median(x["values"][k] for x in ss) for k in ss[0]["values"]} for v,ss in versions.items()}
        for v,ss in versions.items():summary[key][v]["rss_KiB"]=statistics.median(x["rss_KiB"] for x in ss)
    result={"experiment":a.experiment,"generated_sources_identical":True,"head":output("git","rev-parse","HEAD").strip(),"cpu":cpu,
            "nim":output("nim","--version").splitlines()[0],"gcc":output("gcc","--version").splitlines()[0],
            "repeats":a.repeats,"native_provider":provider,"native_sha256":{v:sha(BASE/v/"native"/provider) for v in ("before","after")},
            "binary_sha256":{f"{v}/{n}":sha(BASE/v/n) for v in ("before","after") for n in ("stream","latency","small","malloc","storage","layout-default","layout-compact","layout-wide")},
            "summary":summary,"samples":samples}
    (BASE/"results.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(summary,indent=2),flush=True)
if __name__=="__main__":main()
