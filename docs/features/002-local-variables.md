# Feature 002 — Local variables

Status: approved for implementation after Feature 001.

The accepted source form is:

```text
function main() returns Int {
    var salary = 5000;
    var bonus = 500;
    var total = salary + bonus;
    return total;
}
```

This feature adds `var`, local identifiers, multiple statements in a
function body, and sequential lexical local scope.

A local becomes visible only after its initializer has been checked.
Therefore self-reference and forward reference are rejected.

A direct binding-to-binding initializer is also rejected:

```text
var a = 5;
var b = a; // invalid
```

Eido requires explicit relationship semantics for direct reuse of an
existing binding. At the Feature 002 milestone, `copy`/`ref` were future work.
They are now implemented for class-valued local bindings: `copy` creates a
detached class graph and `ref` preserves the same logical object identity.
Primitive bare-identifier initialization remains governed by its existing rules.

Using an identifier as part of a computed expression is valid:

```text
var b = a + 1;
```

At the Feature 002 milestone, only `Int` existed and `set` mutation was not yet implemented. Later features extend both capabilities.
