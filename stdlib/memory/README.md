# eido.stdlib.memory

Public explicit-memory APIs above Eido's compiler-provided `Storage<T>` substrate.

Public API:
- `Memory<T>.arena(capacity)`
- `Arena<T>.create(capacity)`
- `Arena<T>.allocate(count)`
- `Arena<T>.remaining()`
- `Arena<T>.reset()`
- `Arena<T>.release()`

`Memory<T>` is the explicit export root. Its `Arena<T>` result makes Arena transitively public without weakening the rule that stateful classes are not direct module export roots.

The `managed/` child owns the SDK default automatic GC policy/runtime. It is hidden from ordinary application imports but is not compiler-private: its `policySources` use the supported memory-policy API, and a custom policy module may replace it.
