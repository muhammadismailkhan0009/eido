# External memory workload benchmarks

Independent of the conformance suite and original Eido microbenchmarks.

Run from repository root:
```sh
python3 benchmarks/standard/run.py --repeats 3
```
The runner downloads the reference sources into the ignored build tree,
checks their hashes, compiles the current Eido compiler, builds release
executables, validates allocation paths with a separate audit executable,
and runs one warmup plus three recorded rounds in randomized order on
one logical CPU. Requires Linux, Python 3, curl, GCC/G++, Nim, nm, GNU time.
No GC/RC policy or production SDK modifications. Benchmark-private native
support supplies timing, conversion, argument parsing and trace input.

## STREAM-derived variant

John D. McCalpin, STREAM v5.10 (1991–2013):
https://www.cs.virginia.edu/stream/FTP/Code/stream.c
Run rules: https://www.cs.virginia.edu/stream/ref.html
Reference source is downloaded unmodified and compiled with -O3,
STREAM_ARRAY_SIZE=8000000, NTIMES=10, no OpenMP. Eido uses the same four
64-bit floating-point kernels, scalar 3, calibrated initial values, array
size and iteration count; its calibration multiply is folded into initial
assignment outside measurement. Its arrays are dynamic Storage<Float>,
unlike the reference's static C arrays. Each kernel's first iteration is
excluded; bandwidth uses the minimum of the remaining nine times.
Reported values are medians of per-process best rates (decimal MB/s).
Every Eido array element must match the reference recurrence.
These are **results based on a variant of the STREAM benchmark code**,
not an official STREAM submission. Reference attribution and publication
conditions remain those of McCalpin's source.

## malloc-large-derived variant

Source: https://github.com/daanx/mimalloc-bench/tree/acb85084d5a0f071ca6424aaaa06c5b663957e0e/bench/malloc-large
Original workload by Leonid Stolyarov, modified by Daan Leijen.
Original C++ compiled unmodified with -O3. Trace.cpp reproduces libstdc++
MT19937(seed 42) and the two uniform distributions for all 2,000 requests:
20 slots, 5–25 MiB zero-initialized buffers. The Eido port reads this exact
trace before timing. Two explicit owners per slot preserve allocation
before release, with empty descriptors (no backing allocation) for
inactive banks. The extra handle operations are a port-specific difference,
needed because nested owning Storage descriptors are unsupported. The
audit verifies every positive allocation size, matching slot replacement
order, and all releases in a separate binary. Original C++ binary imports
new[], delete[] and memset; Eido uses the existing Storage alloc0 path.
Reported comparison is whole-process wall time, including setup and final
cleanup, and maximum RSS, not identical allocator algorithms or isolated
allocation-call overhead. Eido's internal allocation-loop time is retained
as additional information only.

## Recorded results

See `../results/2026-11-26-standard-mm.json` (raw samples, hashes, audit).
Initial run: Intel i5-1135G7, GCC 14.2.0, Nim 2.2.10, single pinned logical CPU.
The reference and Eido binaries all exited successfully.

| STREAM-derived rates (GB/s) | C reference | Eido |
|---|---:|---:|
| Copy | 30.48 | 3.60 |
| Scale | 17.57 | 3.33 |
| Add | 19.73 | 3.39 |
| Triad | 19.86 | 3.25 |

| malloc-large-derived results | C++ reference | Eido |
|---|---:|---:|
| Median wall seconds | 2.099 | 1.405 |
| Median peak RSS MiB | 520.91 | 603.63 |

Eido shows a substantial bandwidth deficit and a favorable time/memory
trade-off in this specific large-allocation trace. Neither proves general
allocator superiority; Eido safety checks, Nim allocation implementation,
compiler flags, code generation and vectorization differ. No latency,
multi-threaded allocator, GC/RC or physical class-layout benchmark is
claimed by these two tests.


## Dependent-load and small-block follow-up

See [latency/README.md](latency/README.md) and [small-alloc/README.md](small-alloc/README.md).
The matched latency benchmark uses fixed and randomized 64-byte-stride
rings, 4 KiB–64 MiB working sets, C pointers, C indices and Eido Storage<Int>.
The small-block workload uses 8, 32 and 128 byte zero-initialized allocations
and complete byte touches. These are independent variants of established
methodologies, not official upstream scores. The unmodified Ubuntu lmbench
executable is an additional contextual reference. The original cache-scratch
worker loses its allocation loop with GCC 14 -O3; its timing is excluded.

Run: `python3 benchmarks/standard/run_latency.py --rounds 3 --small-rounds 5`.
Initial results: `../results/2026-11-26-latency-small-mm.json`.


The follow-up was run successfully with one process per latency case (seven
measured trials), five independent small-allocation samples per size and
implementation, and the unmodified lmbench sweep. Representative results:

| Random dependent loads | C indexed (ns) | Eido (ns) |
|---|---:|---:|
| 4 KiB | 1.64 | 3.76 |
| 32 KiB | 1.63 | 3.66 |
| 256 KiB | 5.44 | 6.75 |
| 1 MiB | 8.99 | 9.97 |
| 8 MiB | 94.22 | 95.34 |
| 64 MiB | 133.75 | 138.54 |

| Small allocation/touch/release | C (ns/cycle) | Eido (ns/cycle) |
|---|---:|---:|
| 8 bytes | 24.11 | 66.88 |
| 32 bytes | 33.40 | 239.26 |
| 128 bytes | 103.67 | 877.56 |

These results establish a sufficient initial optimization baseline. Prioritize
Storage access inlining and fixed-stride specialization, redundant-check
elimination with preserved safety, and byte conversion overhead before
expanding benchmarks further.

The ordered optimization backlog and acceptance criteria are maintained in [docs/memory-performance-roadmap.md](../../docs/memory-performance-roadmap.md).


## Native Storage inlining experiment (MM-P01)

Recorded paired results: `../results/2026-11-26-native-storage-inline.json`.
Same compiler, generated Nim, workload inputs and native SDK except for six
inline pragmas. One warmup and three recorded repeats per variant, 25
workloads. Reproduce while the production source contains exactly those
pragmas relative to the original:

```sh
mkdir -p benchmarks/build/inline-comparison
git show c577c00:stdlib/native/nim/eido_storage.nim > benchmarks/build/inline-comparison/original-storage.nim
python3 benchmarks/standard/compare_inline.py --baseline benchmarks/build/inline-comparison/original-storage.nim --repeats 3
```

The paired runner checks workload results and saves complete disassembly.
Independent audits were run against the exact measured optimized binaries
and preserved in the recorded JSON. The original and standard audits now
accept verified inlined memory-access paths as well as explicit calls.


## Native Storage guarded stride experiment (MM-P02)

Baseline is the committed inline-only provider (dedb6ed), not the original
pre-inline implementation. This experiment was rejected and reverted;
the following historical reproduction command requires reapplying the
guarded stride candidate described in the roadmap first:
```sh
mkdir -p benchmarks/build/stride-comparison
git show dedb6ed:stdlib/native/nim/eido_storage.nim > benchmarks/build/stride-comparison/original-storage.nim
python3 benchmarks/standard/compare_inline.py --experiment stride --baseline benchmarks/build/stride-comparison/original-storage.nim --repeats 3
```
The runner checks the exact native-source delta and identical generated Nim.
See `../results/2026-11-26-native-storage-stride.json` for all samples and
median paired changes. Workload performance is mixed; no broad speedup.


## Native Byte conversion inline experiment (MM-P04)

Run against the saved original native bytes provider:
```sh
python3 benchmarks/standard/compare_inline.py --experiment byte-inline --baseline benchmarks/build/byte-inline-comparison/original-bytes.nim --repeats 3
python3 benchmarks/standard/compare_byte_focused.py
```
Rejected and reverted. Historical reproduction requires reapplying the two
candidate pragmas first. The original provider is
a copy of the pending SDK source before those pragmas; it is not part of
dedb6ed. Recorded results and both providers' hashes are in
`../results/2026-11-26-native-byte-inline.json`.


## Native allocator comparison (MM-P06)

Rejected as a general-purpose replacement and reverted. The historical
candidate patch, raw samples, independent audits, and page-touch profile
are stored in `../results/2026-11-26-native-allocator-comparison.json`.
To reproduce, reapply the recorded candidate patch to the MM-P01
native Storage provider, save the original provider as the baseline, then:

```sh
python3 benchmarks/standard/compare_inline.py --experiment allocator --baseline benchmarks/build/allocator-comparison/original-storage.nim --repeats 3
for v in before after; do
  nim c -d:release --hints:off --path:benchmarks/build/allocator-comparison/$v/native --nimcache:benchmarks/build/allocator-comparison/$v/profile-cache -o:benchmarks/build/allocator-comparison/$v/profile benchmarks/standard/malloc-large/Profile.nim
done
python3 benchmarks/standard/compare_allocator_profile.py
```

The profile is a separate native diagnostic using the exact same allocation
trace; zero-only and page-touch modes distinguish resident retention from
the cost of physically accessing pages. It is not a full Eido workload.

## Standalone benchmark support after platform prototype removal

The historical results above were obtained with the then-pending Bytes/Text/File
SDK. Those public APIs have been discarded for a clean networking redesign.
The current runners instead install private, benchmark-owned support from
`support/` into their isolated native provider copies. The timed Storage
loops and input trace remain the same. Byte conversion helper bodies and the
historical native bytes source are retained for MM-P04 reproduction; numeric
output and trace loading are test-only. The trace file now uses a private
whole-file reader before timing. Historical binary hashes and whole-process
times are not claimed to be identical after this change.
For MM-P04, save `support/eido_native_bytes.nim` as the original provider and
apply the two historical inline hints to that fixture, not to stdlib.
