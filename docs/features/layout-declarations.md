# Eido memory layouts (builder and raw-backend milestones)

Status: **declarations, compile-time builder, and offset-based class backend
implemented**. Named layouts are evaluated and validated, but are not selected
or applied yet. The default Eido layout is the active physical representation.

## Named layout definitions

```eido
class Family {
    String father;
    String mother;
}

layout Compact for Family {
    var shape = Layout.create();
    shape.field("father");
    shape.field("mother");
    return shape;
}

layout Aligned for Family {
    var shape = Layout.create();
    shape.field("mother");
    shape.field("father");
    shape.align(16);
    return shape;
}
```

Multiple named layouts may target one class. Layouts can be declared in a
separate Eido source file. The project's regular module system resolves class
targets; no new module YAML configuration is required.

Generic layout templates are supported at declaration level:

```eido
class Pair<A, B> {
    A first;
    B second;
}

layout Reverse<T, U> for Pair<T, U> {
    var shape = Layout.create();
    shape.field("second");
    shape.field("first");
    return shape;
}
```

A generic layout declaration is instantiated only for concretely used class
specializations and does not itself trigger class instantiation.

## Current compiler behavior

- The frontend parses layout bodies as Eido statements and retains them in the
  AST and HIR. The build-machine Eido compiler type-checks and executes them.
- Declarations must name an existing *class* target; duplicate layout names
  are rejected. Generic layout parameters must match the target template.
- Each layout body must end with a value-returning `return` statement.
- Compile-time `Layout` supports `create()`, `field(name)`,
  `fieldAt(name, offset)`, `align(bytes)`, `size()`, `offsetOf(name)`,
  and the internal `submit()` operation.
- Its field placement and final size calculations execute in Eido. The
  compiler supplies semantic field/type facts and validates the finished
  placement (completeness, overlaps, alignment, bounds).
- Layouts are evaluated even when no automatic memory policy is selected;
  evaluation cannot change the runtime allocation policy.
- No `LayoutPolicy.select` API exists, and all declarations are currently
  unselected and have no effect on the generated executable.
- The Nim backend now uses Eido-computed byte offsets for class fields.
  Opaque, byte-only Nim buffer types still represent `Storage<Class>` slot
  size and alignment; they contain no class-field layout declarations.
- The Eido compiler's default layout builder continues to supply the active
  representation until named-layout selection is implemented.
- Public Storage APIs and GC/RC policies are unchanged.

## Not yet implemented

- `LayoutPolicy.select()` and any named-layout selection or override mechanism.
- Applying a named layout to Storage or managed objects; only the default
  computed layout drives physical memory until selection exists.
- Richer field representations such as bit packing, unions, AoS/SoA, and
  variable-sized layouts.
- External helper imports into layout bodies; these compile as private
  build-machine Eido methods with the provided Layout, FieldInfo and
  StorageInfo APIs.
- Public `Storage.define()` or `Memory.manage()` APIs.

No public Storage, GC, or RC API was changed.
