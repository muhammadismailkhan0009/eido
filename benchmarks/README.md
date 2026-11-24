# Memory-management API benchmarks

Standalone native benchmarks of Eido's public memory-control abstractions,
not collector implementations or conformance tests. They do not run as
part of `nimble test`.

From the repository root on Linux x86-64, with Nim, Python 3, a C compiler,
GNU time, gdb, nm and objdump installed:

```sh
python3 benchmarks/run.py --repeats 9
```

The runner builds the current CLI and all programs with the normal release
build path. Use `--skip-build` only when the built inputs match the current
sources. Every measured executable is fingerprinted.

## Workloads

| Folder | Workload | Comparison |
|---|---|---|
| storage | 2M int64 writes, 24M reads | Typed allocation vs raw backing + typed view vs native SDK vs Nim sequence |
| storage | 1M iterations, one int64 write/read, 16-slot buffer | Allocate/release vs reserve/release vs reuse, plus native SDK equivalents |
| layouts | 2M inline four-field rows, initialized once and scanned 12 times | Default, compact, 64-byte-aligned, compared against identical native Nim structs |
| inline-policy | Allocation rejection guard | No lifecycle handlers or automatic allocation; not a timed policy benchmark |

Primitive Storage uses `--memory=none`. The compiler currently requires a
selected policy for programs with identity-bearing classes, even if they
only construct objects inline. The user-defined inline-only policy binds
only the object acquisition event, aborting with exit code 91 if it is
invoked. It binds no lifecycle handlers. A negative control deliberately
constructs a standalone Row to confirm the guard actually rejects it.

All layout variants are built from the same source with only compile-time
layout selection changed. Native Nim structs have independently asserted
sizes, field offsets and alignments. Their raw aligned allocations and
typed pointer accesses are lower-level baselines without Storage checks.
Bare Nim allocation churn uses a volatile read to prevent the compiler
from removing the immediate load.

## Execution-path audit

`python3 benchmarks/audit.py` runs the audit alone after building.

- The actual timing binaries perform an independent raw-memory round trip
  and GDB inspection of live row stride, capacity, alignment, and field
  values at the real constructor and scan call sites.
- Separate instrumented release builds verify exact counts of Storage
  allocation, release, placement, read/write, inline construction, and
  field access. The measured binaries contain no counters.
- The generated layout code must contain no memory-policy lifecycle
  handlers; its temporary-scope template must be a compile-time identity.
  The guard's negative control must fail with the expected exit code.
- Native machine code is inspected for real Storage calls. Disassembly of
  the independent native reference implementations is saved for review.
- Failure aborts the benchmark before timing. The audit is intentionally
  codegen-sensitive and the debugger probe is Linux x86-64-specific.

## Measurement

One warmup, then seven recorded rounds by default, shuffled with a fixed
seed. All runs are serial and pinned to a single logical CPU where supported.
External wall-clock duration includes startup, allocation, initialization,
scan and release; compilation/audit are excluded. Every run checks its
checksum. GNU time reports peak RSS. Median, range and individual samples
are retained. Short cases are sensitive to startup cost and CPU conditions.

The native SDK baselines use the same native substrate but omit the Eido
typed allocation/alignment/ownership wrapper, so their validation
guarantees differ. The direct Nim struct/sequence and bare allocation
references are lower-level comparisons, not equivalent safety contracts.

This suite measures specific sequential microbenchmarks, not overall
application speed, cache-miss rates, all copy/ref semantics, or C/Rust
performance. See RESULTS.md. Generated code, debugger transcripts,
disassembly and logs live under ignored `benchmarks/build/`.
