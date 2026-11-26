# Memory performance optimization roadmap

Status: MM-P01 implemented, benchmark-validated and committed (dedb6ed); MM-P02 rejected and reverted; MM-P03 deferred; MM-P04 rejected and reverted; MM-P05 deferred; MM-P06 deferred and reverted. Baseline: 2026-11-26.
The objective is to reduce the cost of the existing memory capabilities,
not benchmark or redesign individual GC/RC policy implementations.

## Evidence

- `benchmarks/results/2026-11-26-standard-mm.json`: STREAM-derived bandwidth
  (Eido 3.25–3.60 GB/s; C 17.57–30.48 GB/s depending on kernel), large allocation
  trace (Eido 1.405 s, 604 MiB RSS; C++ 2.099 s, 521 MiB RSS).
- `benchmarks/results/2026-11-26-latency-small-mm.json`: randomized dependent
  loads at 4 KiB (Eido 3.76 ns, C index 1.64 ns) and 64 MiB (138.54 ns versus
  133.75 ns); small allocation/touch/release (2.8–8.5x C time, depending on size).
- Generated optimized machine code retains Storage read/write and slot-address
  calls, runtime stride multiplication, descriptor liveness and bounds checks.
  The relative contributions of these costs remain to be isolated.
- External workload variants have different safety/allocator/compiler properties;
  these are optimization baselines, not claims of equivalent unchecked semantics.

## Ordered priorities

| ID | Priority | Work | Status |
|---|---|---|---|
| MM-P01 | P0 | Native Storage read/write and checked-address inlining | Implemented; focused tests and benchmarks passed |
| MM-P02 | P0 | Guarded native constant-stride address calculation | Rejected; reverted (performance trade-off) |
| MM-P03 | P0 | Eliminate or hoist provably redundant liveness/bounds checks | Deferred; requires reliable proof or existing backend support |
| MM-P04 | P1 | Native Byte conversion inlining | Rejected; reverted (no speedup) |
| MM-P05 | P1 | Backend auto-vectorization | Deferred; prioritize future Eido Vector API |
| MM-P06 | P2 | Native allocation provider replacement | Deferred; reverted (memory/speed trade-off) |

## MM-P01: first optimization

The approved scope is native SDK-local Nim inline pragmas only. Do not add
an Eido inlining pass, compiler-side inline-selection heuristics, source
keywords, or special lowering of Storage's public Eido method bodies.
The six native functions are requireEidoStorageLive, requireEidoStorageIndex,
eidoStorageSlotAddress, eidoStorageSlotIdentity, eidoStorageRead and
eidoStorageWrite. Their logic is unchanged.

Paired current-toolchain comparison (one warmup, three recorded repetitions,
25 workloads, 150 recorded executions; identical generated Nim for both
variants) is in `benchmarks/results/2026-11-26-native-storage-inline.json`.
STREAM bandwidth rose 2.38–2.62x, typed/raw scan time fell ~45%, 32-byte
allocation/touch/release time fell ~47%, compact layout scan time fell
~19%. Large allocation was unchanged. Dependent-load latency was mixed;
8 MiB fixed/random median latency increased ~13%/~10% in this sample,
while 64 MiB random latency was ~1.6% higher. Recheck these when profiling
subsequent changes. The STREAM binary's static call sites to native
read/write/slot-address helpers went from 43 to zero. Runtime stride and
safety checks remain in emitted machine code. No general-purpose Eido
inliner is warranted by this experiment.

Verification: 10 native boundary tests (including new read/write/slot
identity negative tests), all 20 Storage-related regression selectors
(including RC and String Storage), all 8 original physical audit cases,
all 3 native layout probes, 2,000 large and 4,096 small allocations and
matching releases. The full unfiltered regression suite was not rerun for
this focused native change. Retain the pragmas; no other optimization
priority has been retained.

## MM-P02: guarded stride experiment

Native-only experiment: check whether the descriptor stride equals
`sizeof(T)`, use a constant byte scale if true, otherwise preserve the
original dynamic multiply. Liveness/bounds validation precedes both paths.
No added fields, API arguments, syntax, compiler rules or optimization passes.
The existing typed and raw capabilities may have wider strides than their
element type, so the fallback is mandatory.

Paired baseline: `dedb6ed` (MM-P01 already present). Identical generated Nim,
one discarded warmup and three independent recorded repetitions per variant,
25 cases / 150 measured executions. Results:
`benchmarks/results/2026-11-26-native-storage-stride.json`.
Generated code uses constant-scale arithmetic for the matching case but
retains a runtime stride comparison/branch within the STREAM loops.

Ratios of medians: typed scan +13.8% time, raw scan +24.6%, small-block
allocation/touch/release +17.2%/+37.7%/+28.9% (8/32/128 B); storage reuse
-8.4%; randomized loads at 4/32 KiB -14.5%/-19.4%, 64 MiB -0.2%.
STREAM medians were mixed, with median paired bandwidth changes of
-1.0%, +4.8%, -0.6%, -2.7% (Copy/Scale/Add/Triad). Run-to-run variability
was substantial; paired comparisons also show regressions for small blocks
and original scans. No compelling overall throughput gain. Physical layout
raw round trips and native debugger probes passed on 32/24/64-byte layouts.
All 11 direct native boundary tests, 20 Storage regression selectors and
8 original physical audit cases passed; full unfiltered suite and independent
external allocation-count audits were not rerun for this experiment.

Decision: rejected and reverted on 2026-11-26. The runtime stride
comparison and branch remained in the hot loop, offsetting the cheaper
address arithmetic and causing scan and small-block regressions. Preserve
the historical measurements; revisit only when the backend can prove or
hoist the stride condition outside hot loops without introducing Eido
compiler complexity. MM-P01 remains the production baseline. The native
change and experiment-specific test/audit modifications were reverted;
no other optimization has been implemented.

## MM-P03: redundant safety-check elimination

Decision (2026-11-26): deferred at user direction. Keep all existing
liveness and bounds checks. Safe elimination or hoisting depends on
proving index ranges, descriptor validity and absence of invalidating
effects across calls and aliases, while preserving failure behavior and
ordering. An individual native Storage access lacks that context.
Do not introduce a bespoke compiler analysis pass or unchecked access
solely for performance on the current Nim backend. Revisit if existing
backend optimization can establish the necessary facts or a future
backend makes the analysis practical. No implementation attempted.

## MM-P04: native Byte conversion inlining

Add Nim inline hints only to Bytes.unsigned and Bytes.fromUnsigned.
No representation, SDK API, compiler, Storage or range-validation changes.
All 256 byte patterns round-trip; four invalid input values raise ValueError.
The enterprise network integration suite also passed.
The small-block executable has three static calls to the conversion helpers
before the change and none afterward.

Paired benchmark against MM-P01, with identical generated Nim and only
the two inline pragmas changed: 25 cases, 150 measured executions.
Recorded in `benchmarks/results/2026-11-26-native-byte-inline.json`.
STREAM bandwidth changed by less than 0.5% across kernels. Small-block
allocate/touch/release median time increased 4.3%, 8.9%, 7.1% for 8, 32,
128 bytes. Nine additional recorded pairs per size confirmed the result:
44.02 -> 44.26 ns, 122.36 -> 127.10 ns, 436.23 -> 470.27 ns per cycle;
median paired time changes +1.9%, +6.7%, +8.1%. The cause of the regression
is not isolated. Do not assume call removal implies faster execution.
Decision (2026-11-26): rejected and reverted at user direction. The
conversion calls disappeared but the measured small-block workload became
slower, including in nine additional paired repetitions. Keep the original
conversion procedures and validation. Experiment-specific test registration
and test file were removed; retain measured evidence and reproduction scripts.
No protocol throughput claim is supported by these memory benchmarks.

## MM-P05: vectorization direction

Decision (2026-11-26): defer automatic vectorization as a current backend
optimization. SIMD remains a target capability, to be exposed through
a future explicit Eido Vector API rather than a Nim-specific optimization
or bespoke automatic vectorization pass. Design the feature at the Eido
level and provide target-specific lowering when supported. No API design
or implementation is locked by this decision.

## MM-P06: native allocation provider experiment

Replace only the native Storage backing pair `alloc0/dealloc` with
`calloc/free` in separate builds. Preserve zero initialization, address
alignment, original backing identity, allocation ownership, and public API.
No compiler, SDK interface, GC/RC, or policy changes.

Paired comparison against MM-P01: 25 workloads, three measured repetitions
per variant (150 recorded executions). Results:
`benchmarks/results/2026-11-26-native-allocator-comparison.json`.
Peak RSS on the Eido large-allocation trace fell 618232 -> 473788 KiB
(-23.4%), while median process time fell 1499.38 -> 1418.11 ms (-5.4%).
Small-block cycle times increased 4.2%, 5.9%, 9.6% for 8/32/128 bytes.
One million Storage allocation/release cycles increased 75.32 -> 136.19 ms
(+80.8%). STREAM bandwidth was essentially unchanged.

Independent native diagnostic replayed the exact 2000-operation trace
(peak requested live bytes 416442509) in zero-only and page-touch modes.
Three timed pairs per mode, separate diagnostic snapshots. Zero-only
peak RSS: 579784 -> 474036 KiB; wall time 1.41 -> 1.64 s. Writing one
byte per page plus endpoint: peak RSS 579704 -> 532620 KiB; wall time
1.55 -> 2.50 s (+61.3%). Minor faults 144691 -> 1018017; total release
time 1.47 -> 127.80 ms. Post-release diagnostic RSS after 100 ms idle:
579908 -> 1748 KiB in page-touch mode. The original allocator retains
resident memory for reuse in this trace; the alternative returns most
pages. Not a leak diagnosis or exact fragmentation accounting.

All 10 native boundary tests, 150 recorded workload executions, and
independent large (2000 allocations/releases) and small (4096 allocations/
releases) audits passed. Full regression suite and original custom physical
audit were not rerun. Historical C++ reference was not rerun. No universal
performance superiority claimed.

Decision (2026-11-26): defer and revert the universal allocator replacement.
The real memory-footprint and retention improvements do not justify
the substantial regression in general-purpose churn and physically used
large-memory workloads. Keep the MM-P01 allocator for now. Revisit
when workload-specific allocation strategies or explicit memory-retention
requirements justify a different trade-off. Preserve raw samples,
diagnostic source, candidate patch, and reproduction tooling.

## Acceptance and measurement

- Preserve all public behavior: bounds/liveness failures, raw and typed views,
  slices, alignment, custom strides/layouts, copy/ref semantics, selected
  memory policies and explicit ownership. Do not introduce unsafe shortcuts.
- Apply one optimization at a time, inspect generated Nim and optimized native
  disassembly, run targeted semantic/native tests including negative cases,
  then the regression suite before declaring full release validation. Report focused-test scope explicitly.
- Rebuild and rerun the existing benchmark workloads and independent audits
  using matching flags, sizes, CPU affinity and repeated measurements.
  Compare STREAM, fixed/random latency, small/large allocation, original
  Storage/layout cases and RSS. Record sample distributions, not just best
  observations. If possible, isolate effects with a same-toolchain baseline.
- Update this roadmap with implementation status, verification and measured
  trade-offs; retain pre-optimization samples. No arbitrary speed target
  or claim of eliminated overhead without measured evidence.
- Defer additional benchmark families unless an optimization exposes a
  specific coverage gap. Keep Python orchestration, Eido workloads, and
  separate upstream reference implementations.
