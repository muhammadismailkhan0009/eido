# Cross-component integration tests

This root-level test area is reserved for tests spanning compiler, installed SDK, stdlib, packages, tools, or installer behavior. Compiler and language conformance tests live under `compiler/tests/`.

## OS-managed TCP networking

`EIDO_TEST_FILTER="Integration::TCP networking" nimble test` builds the ordinary
Eido fixture under GC and RC, uses separate localhost IPv4/IPv6 peers and checks
partial progress, half-close, status handling, timeouts, stride and descriptor
ownership. Linux, Python 3, stdbuf and IPv6 loopback are required; no privileged
network configuration or external service is used.
