# Dependent memory access latency

This is an independently implemented, matched benchmark inspired by lmbench
lat_mem_rd and randomized pointer chasing (e.g. Google multichase). It is
not a modified lmbench binary or an official lmbench result. The original
lat_mem_rd reference can also be run separately using the unchanged Ubuntu
lmbench package (no installation). Its adaptive timing and traversal differ
from the matched experiments and must not be used to calculate Eido speed ratios.

Each measured chain occupies 4 KiB, 32 KiB, 256 KiB, 1 MiB, 8 MiB or 64 MiB.
One dependent link per 64-byte stride. Both Eido and C use the same
64-bit slots and deterministic Fisher-Yates permutation (LCG seed 42);
the fixed-order case visits increasing addresses. A separate native C
pointer baseline stores actual addresses instead of indices. No pointer
dereferencing or benchmark logic is delegated to Nim in the Eido variant.

Each trial traverses a whole number of rings, at least four million loads.
The first timed trial is discarded, seven trials recorded. Validation
verifies that the chain returns to its start only after visiting all nodes,
and each trial ends at the first node. Setup, permutation, validation,
output and release excluded from timing. The timing, integer argument and numeric output hooks are benchmark-owned
and outside the dependent-load loop.

Run from repository root:
```sh
python3 benchmarks/standard/run_latency.py --rounds 3 --small-rounds 5
```
Use --skip-lmbench where the pinned Ubuntu package is unavailable. The
runner builds Eido in release mode, uses --memory=none and pins one logical
CPU. C is GCC -O3. Compare only matched rows: safety checks, generated
representation, compiler flags and native allocator remain different.
These workloads measure dependent access, not sustained bandwidth.
