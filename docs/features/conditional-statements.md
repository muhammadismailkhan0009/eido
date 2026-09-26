# Conditional statements

Eido supports statement-level conditional control flow with `if`, zero or more
`else if` branches, and an optional final `else`.

```eido
if (condition) {
    ...
}

if (condition) {
    ...
} else if (otherCondition) {
    ...
} else {
    ...
}
```

## Conditions

Every `if` and `else if` condition must:

- be enclosed in parentheses;
- have type `Bool`.

Eido does not use truthiness.

```eido
if (count > 0) {
    return count;
}
```

A non-Bool condition such as `if (1) { ... }` is rejected. An
unparenthesized form such as `if ready { ... }` or `else if ready { ... }`
is also rejected.

Mandatory parentheses keep the condition boundary visually distinct from the
branch block.

## Else-if chains

`else if` branches are checked in source order after the preceding conditions
are false. The first matching branch executes. A final `else` is optional.

```eido
if (score >= 90) {
    return 3;
} else if (score >= 70) {
    return 2;
} else if (score >= 50) {
    return 1;
} else {
    return 0;
}
```

Internally, `else if` is parsed as a nested conditional in the previous
conditional's else branch. This reuses the same AST, HIR, scoping, typing, and
definite-return rules as ordinary nested `if` statements.

## Branch scope

Each branch is an isolated local scope:

- outer locals and parameters are visible inside a branch;
- assignments to existing outer variables are allowed;
- locals declared inside one branch do not leak outside it or into sibling branches;
- local semantic IDs remain unique across the whole function.

Current Eido binding rules still reject redeclaring an already-visible parameter
or local name inside a branch.

## Return coverage

A single-result function must definitely return on every path.

A final `if` / `else if` / `else` chain satisfies that contract when every
branch definitely returns and the chain ends with `else`.

```eido
function classify(Int value) returns Int {
    if (value < 0) {
        return -1;
    } else if (value == 0) {
        return 0;
    } else {
        return 1;
    }
}
```

A chain without a final `else` cannot by itself satisfy a result function's
final return requirement because unmatched conditions fall through. Nested
conditionals are checked recursively.

There is no ternary conditional expression yet.
