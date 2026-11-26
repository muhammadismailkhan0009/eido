"""Verify benchmark paths; instrument only an independent allocation audit binary."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import os
from run import ROOT, HERE, BUILD, sha, run

def main():
    support = BUILD/"audit-native"
    shutil.copytree(BUILD/"native", support, dirs_exist_ok=True)
    p = support/"eido_storage.nim"
    s = p.read_text()
    anchor = next(a for a in ('  result.data = cast[ptr UncheckedArray[int8]](alloc0(byteCount))', '  result.data = cast[ptr UncheckedArray[int8]](systemAllocate(1, csize_t(byteCount)))') if s.count(a)==1)
    assert s.count(anchor)==1
    s = s.replace(anchor, anchor+'\n  if byteCount >= 5242880:\n    stderr.writeLine("A " & $cast[uint](result.data) & " " & $byteCount)')
    anchor = next(a for a in ('    dealloc(base)', '    systemRelease(base)') if s.count(a)==1)
    assert s.count(anchor)==1
    s = s.replace(anchor, '    stderr.writeLine("F " & $cast[uint](base))\n'+anchor)
    p.write_text('import std/syncio\n'+s)
    compiler = BUILD/"eido" if (BUILD/"eido").exists() else ROOT/"eido"
    run(compiler,"build",HERE/"malloc-large/module.yaml","--memory=none","-o",BUILD/"malloc-audit",
        env=dict(os.environ,EIDO_NATIVE_NIM_PATH=str(support)))
    proc = run(BUILD/"malloc-audit",BUILD/"trace.txt",capture_output=True,text=True)
    trace = [tuple(map(int,l.split())) for l in (BUILD/"trace.txt").read_text().splitlines()]
    active = {}
    owners = {}
    pending = None
    count = 0
    peak = 0
    frees = 0
    for line in proc.stderr.splitlines():
        if line.startswith("A "):
            _,addr,size=line.split()
            addr,size=int(addr),int(size)
            assert pending is None, (count,pending)
            slot,expected=trace[count]
            assert size==expected and addr not in active
            active[addr]=size
            peak=max(peak,sum(active.values()))
            pending=owners.get(slot)
            owners[slot]=addr
            count+=1
        elif line.startswith("F "):
            addr=int(line.split()[1])
            if addr in active:
                if count<2000 or pending is not None:
                    assert addr==pending, (count,addr,pending)
                    pending=None
                del active[addr]
                frees+=1
        else:
            raise AssertionError(line)
    assert count==frees==2000 and not active and pending is None
    # The timed Eido binary must use actual native Storage operations; no
    # collection callbacks or standalone managed object allocation.
    ev={}
    for name in ["stream","malloc"]:
        gen=(BUILD/f"{name}_eido_generated.nim").read_text()
        assert "eidoStorageAllocateRaw(" in gen
        assert "eidoStorageRelease[" in gen
        assert "template eidoMemoryTemporaryScope(body: untyped): untyped = body" in gen
        if name=="stream":
            assert "eidoStorageRead[float64]" in gen and "eidoStorageWrite[float64]" in gen
        symbols=subprocess.check_output(["nm","-C",BUILD/f"{name}-eido"],text=True)
        assert "eidoStorageAllocateRaw" in symbols and "eidoStorageRelease" in symbols
        if name=="stream":
            if not ("eidoStorageRead" in symbols and "eidoStorageWrite" in symbols):
                asm=subprocess.check_output(["objdump","-d","-C",BUILD/f"{name}-eido"],text=True)
                assert "imul" in asm and "raiseExceptionEx" in asm
                (BUILD/"stream-native.asm").write_text(asm)
                # Validate the actual timed executable with the full array oracle.
                p=run(BUILD/f"{name}-eido",capture_output=True,text=True)
                assert p.stdout.splitlines()[0]=="VALID"
        ev[name]={"binary_sha256":sha(BUILD/f"{name}-eido"),"generated_sha256":sha(BUILD/f"{name}_eido_generated.nim")}
    results={"malloc_allocations":count,"malloc_frees":frees,"peak_requested_live_bytes":peak,
             "exact_trace_and_replacement_order":True,"timed_binary_evidence":ev,
             "note":"Allocation audit is a separate binary, excluded from timings; STREAM validates every array element on each run."}
    (BUILD/"audit.json").write_text(json.dumps(results,indent=2)+"\n")
    print(json.dumps(results,indent=2))
if __name__=="__main__":main()
