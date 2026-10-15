# Eido reference-counting memory policy

This example exercises the SDK reference-counting memory policy `eido.stdlib.memory.rc` against ordinary class/object code.

The policy implementation itself lives under `stdlib/memory/rc/` and is written entirely in Eido over `Storage<T>`. The compiler/backend contains no RC algorithm.

## Run

```bash
eido run module.yaml --memory=eido.stdlib.memory.rc
```

The demo prints `42`.

## Runtime architecture

```text
compiler generic events
        ↓
eido.stdlib.memory.rc/policy.eido
        ↓
RcPolicyRuntime
        ↓
RcValueRegistry + RcTypeRegistry + RcRuntime
        ↓
Storage<T>
        ↓
physical backend allocation
```

## Algorithm

The SDK RC policy uses deferred/recounting reference counting. The existing generic memory API reports lexical/class-owned binding lifetimes, object layout metadata, and stable execution boundaries, so no RC-specific compiler hook is required.

At a stable execution boundary the policy:

1. resets every live object's reference count;
2. counts active identity-bearing bindings;
3. scans compiler-described identity fields and counts incoming object references;
4. releases objects whose incoming count is zero;
5. repeats until no additional zero-count objects remain.

This is reference counting rather than reachability tracing. An unreachable cycle therefore keeps positive internal counts and is not reclaimed during normal execution. Remaining objects are released unconditionally at process shutdown.

## Verified behavior

For an acyclic `Parent -> Child` graph, targeted generated-code assertions observed:

```text
live objects after shutdown       = 0
reclaimed at normal boundaries    = 2
forced releases at shutdown       = 0
```

For a two-node cycle:

```text
reclaimed at normal boundaries    = 0
forced releases at shutdown       = 2
```

The cycle behavior is the expected limitation of simple reference counting and distinguishes this policy from the tracing GC.

## Architectural conclusion

The same class/object program can run with either `eido.stdlib.memory.managed` or `eido.stdlib.memory.rc`. Both use the same compiler-facing memory-policy API and `Storage<T>` substrate; only the Eido policy/runtime implementation changes.

An immediate retain/release RC could later use a generic object-field mutation event to update counts incrementally, but the current deferred RC demonstrates that the existing API is already sufficient for a useful second policy.
