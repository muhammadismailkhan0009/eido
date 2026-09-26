# While statements

Eido supports pre-condition `while` loops.

```eido
while (condition) {
    ...
}
```

## Conditions

The condition must be enclosed in parentheses and must have type `Bool`.

```eido
var count = 0;

while (count < 10) {
    count = count + 1;
}
```

Eido does not use truthiness, so `while (1) { ... }` is rejected.
Unparenthesized conditions such as `while ready { ... }` are also rejected.

The condition is evaluated before every iteration. If it is false initially,
the body executes zero times.

## Body scope

A loop body is an isolated local scope:

- outer locals and parameters are visible inside the body;
- existing outer variables may be reassigned;
- locals declared inside the loop body do not leak outside the loop;
- nested loops and conditionals are allowed;
- function-wide LocalIds remain unique for loop-local declarations.

An empty loop body is valid.

## Return coverage

A `while` statement never counts as definitely returning for function-result
analysis, even when its condition is the literal `true` and its body returns.

```eido
function value() returns Int {
    while (true) {
        return 1;
    }
}
```

The function above is rejected because Eido currently does not use constant-flow
proofs to establish that a loop must execute. This keeps return analysis
conservative and sound.

## Related loop control

`break;` and `continue;` are supported inside while loops and target the
nearest enclosing loop. See `loop-control-statements.md`.

The current loop family still does not include `do while` or `for` loops.
