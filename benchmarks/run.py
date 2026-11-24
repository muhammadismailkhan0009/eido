#!/usr/bin/env python3
"""Build current sources; benchmark sequentially, validate every result."""
import argparse
from audit import audit, digest
import json
import os
import platform
from pathlib import Path
import random
import shutil
import statistics
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
BENCH = ROOT / "benchmarks"
BUILD = BENCH / "build"
CLI = BUILD / "eido"
N = 2_000_000
PASSES = 12
CHURN = 1_000_000

def run(*args, **kwargs):
    return subprocess.run([str(x) for x in args], cwd=ROOT, check=True, **kwargs)

def build():
    BUILD.mkdir(exist_ok=True)
    run("nim", "c", "-d:release", "--hints:off", "--path:compiler/src",
        f"-o:{CLI}", "tools/cli/src/eido.nim")
    run(CLI, "build", BENCH / "storage/module.yaml", "--memory=none",
        "-o", BUILD / "storage-none")
    run("nim", "c", "-d:release", "--hints:off", "--path:stdlib/native/nim",
        f"-o:{BUILD / 'native-storage'}", BENCH / "native/storage.nim")
    run("nim", "c", "-d:release", "--hints:off",
        f"-o:{BUILD / 'native-layout'}", BENCH / "native/layout.nim")
    for variant in ("default", "compact", "wide"):
        project = BUILD / "layouts" / variant
        project.mkdir(parents=True, exist_ok=True)
        shutil.copytree(BENCH / "inline-policy", project / "inline-policy", dirs_exist_ok=True)
        (project / "Main.eido").write_text((BENCH / "layouts/Main.eido").read_text())
        sources = "  - Main.eido\n"
        if variant != "default":
            sources += "  - Selection.eido\n"
            (project / "Selection.eido").write_text(
                f'LayoutPolicy.select("Row", "{variant.title()}");\n')
        (project / "module.yaml").write_text(
            f"module: layout_bench\nsources:\n{sources}"
            "children:\n  inline_policy: { path: inline-policy }\n"
            "dependencies: []\nexports: []\nprovides: {}\nadopts: []\n")
        run(CLI, "build", project / "module.yaml", "--memory=layout_bench.inline_policy",
            "-o", BUILD / f"layout-{variant}")

def measure(binary, mode, expected):
    # Wall-clock process time includes startup, allocation, initialization,
    # scan, release and policy shutdown; build time is excluded.
    start = time.perf_counter_ns()
    p = run("/usr/bin/time", "-f", "%M", binary, mode,
            capture_output=True, text=True)
    ms = (time.perf_counter_ns() - start) / 1e6
    actual = int(p.stdout.strip())
    if actual != expected:
        raise ValueError(f"{binary.name} {mode}: {actual} != {expected}")
    return {"ms": ms, "rss_kib": int(p.stderr.strip())}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--repeats", type=int, default=7)
    parser.add_argument("--skip-build", action="store_true")
    args = parser.parse_args()
    if args.repeats < 3:
        parser.error("need at least three samples")
    if not args.skip_build:
        build()
    # Validate actual physical layout and executable paths before collecting timings.
    evidence = audit()
    for name, expected in evidence["binary_sha256"].items():
        if digest(BUILD / name) != expected:
            raise RuntimeError(f"Binary changed after audit: {name}")
    # Pin only timing runs, not compiler processes.
    cpu = None
    if hasattr(os, "sched_getaffinity"):
        cpu = min(os.sched_getaffinity(0))
        os.sched_setaffinity(0, {cpu})
    scan = PASSES * N * (N + 1) // 2
    churn = CHURN * (CHURN + 1) // 2
    layout = PASSES * N * (N + 2)
    cases = {}
    sizes = {}
    for mode in ("typed", "raw", "churn", "reuse", "placement"):
        cases[f"eido/{mode}"] = (BUILD / "storage-none", mode,
                               scan if mode in ("typed", "raw") else churn)
    for mode in ("array", "sdk", "churn", "sdk-churn", "sdk-reuse", "sdk-placement"):
        cases[f"nim/{mode}"] = (BUILD / "native-storage", mode,
                              scan if mode in ("array", "sdk") else churn)
    for variant in ("default", "compact", "wide"):
        binary = BUILD / f"layout-{variant}"
        sizes[variant] = int(run(binary, "size", capture_output=True, text=True).stdout)
        cases[f"layout/eido/{variant}"] = (binary, "scan", layout)
        cases[f"layout/nim/{variant}"] = (BUILD / "native-layout", variant, layout)
    results = {name: [] for name in cases}
    rng = random.Random(42)
    order = list(cases)
    for round_no in range(args.repeats + 1):
        rng.shuffle(order)
        for name in order:
            sample = measure(*cases[name])
            if round_no:
                results[name].append(sample)
            print(f"{round_no}: {name:18s} {sample['ms']:9.2f} ms {sample['rss_kib']:8d} KiB", flush=True)
    summary = {}
    for name, samples in results.items():
        times = [s["ms"] for s in samples]
        summary[name] = {
            "median_ms": statistics.median(times), "min_ms": min(times),
            "max_ms": max(times),
            "median_rss_kib": statistics.median(s["rss_kib"] for s in samples),
        }
    payload = {"commit": run("git", "rev-parse", "HEAD", capture_output=True, text=True).stdout.strip(),
               "cpu": cpu, "platform": platform.platform(),
               "nim_version": run("nim", "--version", capture_output=True, text=True).stdout.splitlines()[0],
               "repeats": args.repeats, "layout_bytes": sizes,
               "audit": evidence, "summary": summary, "samples": results}
    (BUILD / "results-all.json").write_text(json.dumps(payload, indent=2) + "\n")
    print(json.dumps({k: v for k, v in payload.items() if k != "samples"}, indent=2))

if __name__ == "__main__":
    main()
