# Feature 003 — Primitive reassignment

Status: approved and implemented after Feature 002.

The accepted source form is:

```text
function main() returns Int {
    var salary = 5000;
    salary = salary + 500;
    salary = 6000;
    return salary;
}
```

This feature adds reassignment of an already-declared local `Int` binding.
Assignment is a statement, not an expression, and therefore ends with `;`.

The assignment target must already exist in the current function scope.
The right-hand side may be any currently supported `Int` expression,
including the target itself or another existing primitive identifier.

Examples:

```text
salary = 6000;
salary = salary + 500;
b = a;
```

This does not define assignment semantics for classes, references, or other
non-primitive values. Their `copy` / `ref` semantics remain separate work.
