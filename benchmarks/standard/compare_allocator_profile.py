"""Matched native Storage trace diagnostics, separate from Eido timing."""
import json
import os
from pathlib import Path
import random
import statistics
import subprocess
from run import ROOT, run, sha

BASE = ROOT / "benchmarks/build/allocator-comparison"
TRACE = BASE / "trace.txt"

def main():
    trace = [tuple(map(int, line.split())) for line in TRACE.read_text().splitlines()]
    assert len(trace) == 2000
    owners = {}
    live = peak = 0
    for slot, size in trace:
        live += size
        peak = max(peak, live)
        live -= owners.get(slot, 0)
        owners[slot] = size
    page = os.sysconf("SC_PAGE_SIZE")
    checksum = sum((size-1)//page+1 + int((size-1)%page!=0) for _,size in trace)
    os.sched_setaffinity(0, {min(os.sched_getaffinity(0))})
    def measure(v, mode, diagnostic):
        binary = BASE/v/"profile"
        p = run("/usr/bin/time","-f","%M %R %F %e",binary,TRACE,mode,
                "profile" if diagnostic else "timing",capture_output=True,text=True,timeout=120)
        lines=p.stdout.splitlines()
        assert lines[-1].startswith("RESULT ")
        req, alloc, touch, release, check = map(int,lines[-1].split()[1:])
        assert req == peak and check == (checksum if mode=="touch" else 0)
        rss,minor,major,wall=p.stderr.strip().split()
        d={"peak_requested_bytes":req,"alloc_ms":alloc/1e6,"touch_ms":touch/1e6,
           "release_ms":release/1e6,"peak_rss_KiB":int(rss),
           "minor_faults":int(minor),"major_faults":int(major),"wall_s":float(wall)}
        if diagnostic:
            d["rss_samples"]=lines[:-1]
            d["end_rss_KiB"]=int(next(l for l in lines if l.startswith("END ")).split()[1])
            d["idle_rss_KiB"]=int(next(l for l in lines if l.startswith("IDLE ")).split()[1])
        print(v,mode,d,flush=True)
        return d
    rng=random.Random(71)
    samples={m:{v:[] for v in ("before","after")} for m in ("zero","touch")}
    for i in range(4):
        modes=list(samples); rng.shuffle(modes)
        for mode in modes:
            order=list(samples[mode]);rng.shuffle(order)
            for v in order:
                d=measure(v,mode,False)
                if i: samples[mode][v].append(d)
    profiles={mode:{v:measure(v,mode,True) for v in ("before","after")} for mode in samples}
    summary={m:{v:{k:statistics.median(d[k] for d in s) for k in s[0]} for v,s in a.items()} for m,a in samples.items()}
    result={"page_size":page,"trace_sha256":sha(TRACE),"samples":samples,"summary":summary,
            "profiles":profiles,"binary_sha256":{v:sha(BASE/v/"profile") for v in ("before","after")}}
    (BASE/"profile-results.json").write_text(json.dumps(result,indent=2)+"\n")
    print(json.dumps(summary,indent=2),flush=True)
if __name__=="__main__":main()
