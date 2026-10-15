# eido.stdlib.memory

Namespace for standard memory-management policy implementations.

This module intentionally exports no ordinary application API. Eido's low-level memory capability is compiler-provided `Storage<T>`, and memory-policy authors receive the compiler-facing build-time API under `compiler/compile_time/api/memory_policy/`.

Standard policy children:
- `managed/` — the default tracing GC selected by `--memory=gc`.
- `rc/` — an optional deferred/recounting reference-counting policy selected explicitly as `eido.stdlib.memory.rc`.

Both policies declare `policySources` for compile-time event bindings and ordinary Eido target runtime sources for their allocation/lifetime algorithms. Neither policy has a privileged compiler path; both consume the same generic compiler-facing memory API and allocate through `Storage<T>`.

Applications normally do not import these modules. The compiler selects one through the compilation memory-policy option. Custom project modules may declare their own `policySources` and use the same mechanism.
