# eido.stdlib.memory.rc

Optional SDK reference-counting memory policy implemented entirely in Eido over `Storage<T>`.

Select it explicitly with:

```text
eido run --memory=eido.stdlib.memory.rc
```

The policy is deferred/recounting reference counting. At stable execution boundaries it resets all live-object counts, counts active identity bindings and compiler-described object-field identities, then repeatedly releases objects whose incoming count is zero. This reclaims acyclic unreachable graphs during execution.

Unreachable cycles retain positive internal counts and are therefore not reclaimed by normal RC boundaries. Remaining objects are released unconditionally at process shutdown.

`policy.eido` binds only the public compiler-facing `MemoryPolicy` events. The runtime itself contains no native functions and no backend-specific code; all dynamic backing and bookkeeping are implemented through `Storage<T>`.

The default SDK policy remains `eido.stdlib.memory.managed` (selected by `--memory=gc`). This module exists both as a usable simple policy and as a regression proof that memory management is replaceable without compiler or backend algorithm changes.
