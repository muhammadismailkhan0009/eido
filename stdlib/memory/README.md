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

The `managed/` child owns automatic GC runtime policy and is private to the compiler/runtime.
