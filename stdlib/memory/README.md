# eido.stdlib.memory

Namespace for standard memory-management policy implementations.

This module intentionally exports no ordinary application API. Eido's low-level memory capability is compiler-provided `Storage<T>`, and memory-policy authors receive the compiler-facing build-time API under `compiler/compile_time/api/memory_policy/`.

The `managed/` child is the SDK's default automatic GC policy/runtime. It declares `policySources` for compile-time policy bindings and ordinary Eido runtime sources for allocation, metadata registries, tracing, collection, and shutdown.

Applications normally do not import `eido.stdlib.memory.managed`; the compiler selects it through the default `--memory=gc` policy alias. A project may instead select another module that declares its own `policySources` and implements its runtime over `Storage<T>`.
