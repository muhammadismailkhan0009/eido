import json, os, random, statistics, subprocess
from pathlib import Path
b=Path(__file__).resolve().parents[1]/'build/byte-inline-comparison'
os.sched_setaffinity(0,{min(os.sched_getaffinity(0))})
samples={}
rng=random.Random(71)
for i in range(10):
    sizes=[8,32,128]
    rng.shuffle(sizes)
    for size in sizes:
        order=['before','after']
        rng.shuffle(order)
        for v in order:
            lines=subprocess.check_output([str(b/v/'small'),str(size),'200000'],text=True,timeout=60).splitlines()
            assert lines[-1]=='VALID' and int(lines[1])==200000*size*(size-1)//2
            if i: samples.setdefault(str(size),{}).setdefault(v,[]).append(int(lines[0])/200000)
summary={k:{v:statistics.median(a) for v,a in s.items()} for k,s in samples.items()}
paired={k:statistics.median((a/b-1)*100 for a,b in zip(s['after'],s['before'])) for k,s in samples.items()}
out={'samples_ns_per_cycle':samples,'median_ns_per_cycle':summary,'paired_median_percent_change':paired,'warmup_rounds':1,'recorded_rounds':9}
(b/'focused.json').write_text(json.dumps(out,indent=2)+'\n')
print(json.dumps(out,indent=2),flush=True)
