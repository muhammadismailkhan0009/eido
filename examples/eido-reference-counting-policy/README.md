# Eido reference-counting memory policy

This example is an architecture proof: a memory-management policy other than the SDK GC is implemented entirely as ordinary Eido code and selected through the public compiler memory-policy API. No compiler or Nim implementation change is required.

## Run

```bash
eido run module.yaml --memory=eido_reference_counting_policy.rc
```

The demo prints `42`.

## Policy structure

```text
compiler generic events
        ↓
rc/policy.eido
        ↓
RcPolicyRuntime
        ↓
RcValueRegistry + RcTypeRegistry + RcRuntime
        ↓
Storage<T>
        ↓
physical backend allocation
```

`policy.eido` binds only generic compiler events. It contains no compiler-specific implementation code and the compiler contains no knowledge of `RcRuntime`.

## Algorithm

This is deferred/recounting reference counting. The current generic API reports lexical/class-owned binding lifetimes and object layout metadata, but it does not report each object-field write. Rather than add an RC-specific compiler hook, the policy uses the existing stable execution boundary:

1. Set every live object's reference count to zero.
2. Count active identity-bearing bindings from `bindingEnter`/`bindingWrite`/`bindingLeave` state.
3. Scan each live object's compiler-described identity fields and count those incoming references.
4. Release objects whose incoming count is zero.
5. Repeat until no more zero-count objects can be released.

This is reference counting, not reachability tracing: every incoming edge contributes independently to a count. In particular, an unreachable cycle retains positive internal counts and is not reclaimed during execution.

At process shutdown all bindings are cleared, acyclic objects are reclaimed normally, and any objects still retained solely by cycles are released unconditionally because the process is ending.

## What the proof demonstrated

The acyclic demo allocates a `Parent` containing a `Child`, lets both leave scope, and reclaims both at the caller's next stable execution boundary. Targeted generated-code assertions observed:

```text
live objects after shutdown       = 0
reclaimed at normal boundaries    = 2
forced releases at shutdown       = 0
```

A separate two-node cycle test observed:

```text
reclaimed at normal boundaries    = 0
forced releases at shutdown       = 2
```

That cycle behavior is the expected limitation of simple reference counting and distinguishes this policy from the tracing GC.

## Architectural conclusion

The same class/object program can therefore run with either the SDK mark/sweep GC or this external RC policy without changing compiler or backend implementation code. Allocation and lifetime policy are genuinely supplied by Eido; the compiler supplies only semantic facts/events and `Storage<T>` supplies physical memory.

An immediate retain/release RC implementation would benefit from a generic object-field mutation event so it could update counts incrementally instead of recounting at stable boundaries. This example deliberately does **not** add such an event: it proves a useful second policy using the API exactly as it exists today.
