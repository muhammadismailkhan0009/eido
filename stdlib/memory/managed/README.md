# eido.stdlib.memory.managed

Compiler-private target GC runtime. This module is owned by the SDK but exports nothing to ordinary applications.

- `ManagedGcRuntime` implements heap/header state, allocation, mark/sweep, safepoints, and shutdown in Eido over `Storage`.
- `ManagedGcNative` exposes only machine operations Eido cannot yet express directly, such as precise-root pointer traversal and indirect callbacks.

The compiler removes these sources during initial analysis/planning and injects them only when the selected GC strategy actually needs managed runtime support.
