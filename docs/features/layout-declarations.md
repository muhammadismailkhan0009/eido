# Layout declarations (declaration-only milestone)

Status: **syntax and declaration registration implemented**. Layouts are not
selected, evaluated, or applied to memory yet.

## Proposed source syntax, now parsed

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
  AST and HIR for a future compile-time evaluator.
- Declarations must name an existing *class* target; duplicate layout names
  are rejected. Generic layout parameters must match the target template.
- Each layout body must end with a value-returning `return` statement.
- No compile-time `Layout` builder API exists yet. Body expressions,
  including `Layout.create()`, are **not** type-checked or evaluated in this
  milestone. They are syntax placeholders for later implementation.
- No `LayoutPolicy.select` API exists, and all declarations are currently
  unselected and have no effect on the generated executable.
- Class memory layout still uses existing default metadata and Nim backend
  object payloads until the separate raw-representation milestone.
- Public Storage APIs and GC/RC policies are unchanged.

## Next milestones (not implemented)

Implement the Eido compile-time Layout builder/evaluator, the offset-based raw
class representation, and (separately) a layout-selection mechanism.
