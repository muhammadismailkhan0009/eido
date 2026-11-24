# Memory-management API benchmark results — 2026-11-24

Compiler baseline: `a5722c4989c073a649229b353e8e250dbf5600c5`. Linux x86-64, Intel Core i5-1135G7, Nim 2.2.10, GCC 14.2.0. Release builds; one pinned logical CPU. Nine measured samples plus one warmup per case. 170 checksum-validated runs; eight execution-path audit cases passed. GC/RC performance is outside scope.

Full samples, audit counts and fingerprints: [2026-11-24-mm-apis.json](results/2026-11-24-mm-apis.json).

## Measurements

| Case | Median ms | Min ms | Max ms | Median peak RSS KiB |
|---|---:|---:|---:|---:|
| eido/typed | 71.76 | 69.49 | 111.10 | 16804 |
| eido/raw | 71.89 | 70.36 | 82.46 | 16800 |
| eido/churn | 72.22 | 69.61 | 160.45 | 1236 |
| eido/reuse | 6.60 | 6.42 | 6.94 | 1296 |
| eido/placement | 40.32 | 40.16 | 84.27 | 1192 |
| nim/array | 41.03 | 37.75 | 49.19 | 16808 |
| nim/sdk | 78.43 | 72.26 | 123.54 | 16796 |
| nim/churn | 16.21 | 14.59 | 17.81 | 1192 |
| nim/sdk-churn | 27.90 | 25.89 | 48.15 | 1180 |
| nim/sdk-reuse | 6.87 | 6.06 | 11.01 | 1176 |
| nim/sdk-placement | 23.79 | 21.68 | 29.62 | 1220 |
| layout/eido/default | 116.87 | 114.04 | 158.35 | 63764 |
| layout/nim/default | 89.68 | 84.30 | 110.29 | 63648 |
| layout/eido/compact | 104.54 | 100.19 | 132.18 | 48040 |
| layout/nim/compact | 74.29 | 66.90 | 98.21 | 48064 |
| layout/eido/wide | 187.03 | 182.91 | 273.75 | 126204 |
| layout/nim/wide | 169.29 | 164.10 | 187.62 | 126112 |

## What the results establish

- Physical layout selection: default 32 bytes, compact 24 bytes, wide 64 bytes. Compact uses 25% less payload memory than default, and its median duration is 10.5% shorter in this workload. No policy lifecycle callbacks, no standalone object allocation, exactly one row backing allocation/free, and 24M inline reads in each case.
- Layout access versus direct native Nim: Eido/default 1.30x, compact 1.41x, wide 1.10x native duration. These comparisons include allocation and initialization, and native direct pointer code does not offer equivalent checks.
- Primitive Storage scan: typed 1.75x Nim sequence duration; typed and raw-view scans are close to the native SDK scan. This suggests the native substrate/access path deserves profiling rather than assuming Eido wrappers are the bottleneck.
- Fresh typed allocation is 10.95x reuse duration and 1.79x placement duration. Audit verifies one million physical allocations for fresh allocation, versus one for placement and reuse.
- Typed allocation churn is 2.59x direct native SDK churn; placement is 1.69x direct SDK placement. Typed allocation includes alignment and ownership checks that the baseline omits.

## Verification

Raw memory round-trips and debugger probes inspect the real field offsets, capacity, alignment, and stride in the timing executables. The custom inline-only policy binds only an aborting acquisition handler. All three deliberate standalone-construction negative controls exit 91; all three actual inline workloads succeed. Generated temporary scope is a compile-time identity, not a runtime callback. Instrumented builds count exact calls separately from timings. Native disassembly confirms real storage calls and direct native reference loads/stores.

## Limitations

End-to-end synthetic sequential microbenchmarks on one machine, not cache hardware-counter measurements or application performance. Native bare pointers and native SDK references do not reproduce all Eido checks. Timing ranges overlap for some comparisons; small differences are not reliable claims. Copy/ref isolation, heterogeneous object graphs, custom allocator implementation quality and C/Rust baselines are outside this run. The benchmark guard is necessary because the compiler currently rejects identity-bearing class programs under --memory=none. No production code changes.
