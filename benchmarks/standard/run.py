#!/usr/bin/env python3
"""Run upstream STREAM v5.10 and malloc-large, and corresponding Eido variants."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import random
import re
import shutil
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = ROOT / "benchmarks/standard"
BUILD = ROOT / "benchmarks/build/standard"
UP = ROOT / "benchmarks/build/upstream"
STREAM = "https://www.cs.virginia.edu/stream/FTP/Code/stream.c"
MALLOC = "https://raw.githubusercontent.com/daanx/mimalloc-bench/acb85084d5a0f071ca6424aaaa06c5b663957e0e/bench/malloc-large/malloc-large.cpp"
UPSTREAM_HASHES = {"stream.c": "a52bae5e175bea3f7832112af9c085adab47117f7d2ce219165379849231692b",
                   "malloc-large.cpp": "5781d6954184198277fc70ca476dd1b8e69082be89a9712acb2d0d2b2a31b27e"}
N = 8_000_000
NAMES = ["Copy", "Scale", "Add", "Triad"]
BYTES = [16*N, 16*N, 24*N, 24*N]

def run(*args, **kw):
    return subprocess.run([str(a) for a in args], cwd=ROOT, check=True, **kw)

def output(*args, **kw):
    return run(*args, capture_output=True, text=True, **kw).stdout

def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

def prepare_native(support):
    """Materialize the SDK plus benchmark-private helpers, not public I/O APIs."""
    if support.exists():
        shutil.rmtree(support)
    shutil.copytree(ROOT/"stdlib/native/nim", support)
    for name in ("eido_native_bytes.nim", "eido_benchmark_support.nim"):
        shutil.copyfile(HERE/"support"/name, support/name)
    with (support/"eido_native.nim").open("a") as f:
        f.write("\nimport eido_benchmark_support\nexport eido_benchmark_support\n")

def build():
    BUILD.mkdir(parents=True, exist_ok=True)
    UP.mkdir(parents=True, exist_ok=True)
    for url, name in [(STREAM,"stream.c"),(MALLOC,"malloc-large.cpp")]:
        run("curl", "-fLsS", "--max-time", "30", url, "-o", UP/name)
    for name, expected in UPSTREAM_HASHES.items():
        if sha(UP/name) != expected:
            raise RuntimeError(f"Upstream source changed: {name}")
    run("nim", "c", "-d:release", "--hints:off", "--path:compiler/src",
        f"-o:{BUILD/'eido'}", "tools/cli/src/eido.nim")
    support = BUILD/"native"
    prepare_native(support)
    env = dict(os.environ, EIDO_NATIVE_NIM_PATH=str(support))
    run("python3", HERE/"malloc-large/generate.py")
    for name, project in [("stream-eido","stream"),("malloc-eido","malloc-large")]:
        run(BUILD/"eido", "build", HERE/project/"module.yaml", "--memory=none",
            "-o", BUILD/name, env=env)
    run("gcc", "-O3", f"-DSTREAM_ARRAY_SIZE={N}", "-DNTIMES=10",
        UP/"stream.c", "-o", BUILD/"stream-c")
    run("g++", "-O3", UP/"malloc-large.cpp", "-o", BUILD/"malloc-cpp")
    run("g++", "-O3", HERE/"malloc-large/Trace.cpp", "-o", BUILD/"trace-gen")
    (BUILD/"trace.txt").write_text(output(BUILD/"trace-gen"))

def stream(name):
    p = run("/usr/bin/time", "-f", "%M", BUILD/name, capture_output=True, text=True)
    if name == "stream-c":
        assert "Solution Validates" in p.stdout, p.stdout
        rates = {}
        for label in NAMES:
            m = re.search(rf"^{label}:\s+([\d.]+)", p.stdout, re.M)
            assert m, p.stdout
            rates[label] = float(m[1])
        sample = {"best_MBps": rates, "reference_output": p.stdout}
    else:
        lines = p.stdout.splitlines()
        assert lines[0] == "VALID" and len(lines) == 41, p.stdout
        times = [int(x) for x in lines[1:]]
        assert all(t > 0 for t in times)
        rates = {k: BYTES[i]*1000/min(times[4+i::4]) for i,k in enumerate(NAMES)}
        sample = {"best_MBps": rates, "kernel_ns": times}
    return dict(sample, rss_KiB=int(p.stderr.strip()))

def malloc(name):
    args = [BUILD/name]
    if name == "malloc-eido": args.append(BUILD/"trace.txt")
    start = time.perf_counter_ns()
    p = run("/usr/bin/time", "-f", "%M", *args, capture_output=True, text=True)
    elapsed = (time.perf_counter_ns()-start)/1e6
    sample = {"wall_ms": elapsed, "rss_KiB": int(p.stderr.strip())}
    if name == "malloc-eido":
        sample["allocation_ms"] = int(p.stdout.strip())/1e6
    return sample

def main():
    p = argparse.ArgumentParser()
    p.add_argument("--skip-build", action="store_true")
    p.add_argument("--repeats", type=int, default=3)
    args = p.parse_args()
    if not args.skip_build: build()
    assert args.repeats >= 1
    run("python3", HERE/"audit.py")
    audit = json.loads((BUILD/"audit.json").read_text())
    for name, evidence in audit["timed_binary_evidence"].items():
        assert sha(BUILD/f"{name}-eido") == evidence["binary_sha256"]
    cpu = min(os.sched_getaffinity(0))
    os.sched_setaffinity(0,{cpu})
    names = ["stream-c","stream-eido","malloc-cpp","malloc-eido"]
    samples = {k: [] for k in names}
    rng = random.Random(42)
    for i in range(args.repeats+1):
        rng.shuffle(names)
        for name in names:
            sample = stream(name) if name.startswith("stream") else malloc(name)
            if i: samples[name].append(sample)
            print(i,name,{k:v for k,v in sample.items() if k not in ("kernel_ns","reference_output")},flush=True)
    summary = {}
    for name, ss in samples.items():
        summary[name] = {"median_rss_KiB": statistics.median(s["rss_KiB"] for s in ss)}
        if name.startswith("stream"):
            summary[name]["median_best_MBps"] = {k:statistics.median(s["best_MBps"][k] for s in ss) for k in NAMES}
        else:
            summary[name]["median_wall_ms"] = statistics.median(s["wall_ms"] for s in ss)
            if name == "malloc-eido": summary[name]["median_allocation_ms"] = statistics.median(s["allocation_ms"] for s in ss)
    payload = {"head":output("git","rev-parse","HEAD").strip(),
               "dirty": bool(output("git","status","--porcelain").strip()),
               "cpu":cpu,"cpu_model":next(s.split(":",1)[1].strip() for s in Path("/proc/cpuinfo").read_text().splitlines() if s.startswith("model name")),
               "gcc":output("gcc","--version").splitlines()[0],
               "nim":output("nim","--version").splitlines()[0],
               "repeats":args.repeats,"stream_N":N,"stream_iterations":10,
               "upstream":{STREAM:sha(UP/"stream.c"),MALLOC:sha(UP/"malloc-large.cpp")},
               "binary_sha256":{k:sha(BUILD/k) for k in names},
               "trace_sha256":sha(BUILD/"trace.txt"),
               "audit":audit,"summary":summary,"samples":samples}
    (BUILD/"results.json").write_text(json.dumps(payload,indent=2)+"\n")
    print(json.dumps(summary,indent=2),flush=True)

if __name__ == "__main__": main()
