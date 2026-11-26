# Small-block allocation/access/release

Independent single-worker variant of the allocate-touch-free methodology
of Emery Berger's Hoard cache-scratch benchmark:
https://github.com/daanx/mimalloc-bench/tree/ec3e85908f4cec7e51012a37e2a2c5c0a8680711/bench/cache-scratch

The upstream benchmark targets multithreaded false sharing. This experiment
does not measure false sharing or concurrent allocation. Upstream C++ at
GCC 14 -O3 removes the inner new[]/delete[] pair and replaces heap access
with a stack temporary (checked using objdump). Its timings are not used.
The matched C baseline explicitly uses calloc, volatile byte reads/writes,
and free; Eido uses Storage<Byte> and Bytes.at/put. Both allocate zeroed
blocks, write and read every byte once, accumulate the same exact checksum,
then release. Block sizes 8, 32, 128 bytes, 200,000 cycles per measured run.
Both time the entire allocate/touch/release loop rather than malloc alone.
The C volatile accesses and Eido byte conversion helpers are implementation
differences, not isolated allocator overhead.

A separately instrumented Eido binary verifies 4,096 actual 32-byte
allocations and their corresponding releases. Timed binaries are not
instrumented. Both programs validate checksum and exit successfully.
See ../latency/README.md for runner invocation.
