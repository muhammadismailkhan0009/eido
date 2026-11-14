# Collections

Status: first fixed-size collection slice implemented.

Eido collections are ordinary SDK Eido code built above `Storage<T>`. The compiler does not own Array semantics.

## Public architecture

The first collection is a fixed-size generic array exposed through an interface:

```eido
interface Array<T> {
    function size() returns Int;
    function get(Int index) returns T;
    function setAt(Int index, T value);
    function release();
}
```

Construction is grouped under the exported static generic factory:

```eido
var values = Arrays<Int>.create(3);
values.setAt(0, 40);
values.setAt(1, 2);
var result = values.get(0) + values.get(1);
values.release();
```

The concrete `StorageArray<T>` implementation is module-internal and cannot be named by application modules. Its backing state is:

```text
StorageArray<T>
    ↓
Storage<T>
    ↓
raw Storage<Byte>
```

This preserves the module rule that explicit export roots are interfaces or static-only classes. Collection implementation state does not become a public architectural root.

## Current behavior

- fixed capacity chosen at creation;
- zero-based indexed `get` / `setAt`;
- `size()` reports capacity;
- bounds/liveness checks are inherited from `Storage<T>`;
- `release()` explicitly releases the owned Storage backing;
- ordinary classic `for` loops are sufficient for traversal in the current language.

The underlying `Storage<T>` now supports primitive values, `String`, and inline class payloads. However, the initial generic `Array<T>` implementation has not yet been validated for class-valued `setAt`/`get` against Eido's explicit `ref`/`copy` and detached-return rules. Do not treat `Array<Class>` as supported until those collection API semantics are resolved and covered by native tests. This is a collections-layer limitation, not a missing raw allocator.

## Deferred

The first slice intentionally does not add:

- iterator/generator protocols;
- `for-each` syntax;
- dynamic List growth;
- Map or Set;
- automatic collection resource finalization;
- generic interface inheritance.

Those should be driven by actual collection/application requirements.
