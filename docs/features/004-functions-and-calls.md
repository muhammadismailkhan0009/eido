# Feature 004 — Typed parameters and function calls

Status: approved and implemented after Feature 003.

The accepted source form is:

```text
function main() returns Int {
    var total = add(10, 20);
    return total;
}

function add(Int a, Int b) returns Int {
    return a + b;
}
```

Parameters use Java-style `Type name` ordering. Parameters and call
arguments are comma-separated. `main` remains zero-argument.

The compiler collects all function signatures before checking bodies, so a
function may call another function declared later in the source file.
At the Feature 004 milestone, calls returned `Int` because `Int` was then
the only supported type. Feature 005 later generalizes parameters/results across
all primitive types and adds zero-result functions.

Parameters enter function scope as readable typed bindings. A local `var`
may not redeclare a parameter. Parameter mutation with `set` is intentionally not
defined by Feature 004; only local `var` bindings are currently mutable.

A direct initializer from an existing parameter or local remains invalid:

```text
var other = value; // invalid: future copy/ref semantics must be explicit
```

The Nim backend emits forward procedure declarations so Eido source order
does not determine function-call visibility.
