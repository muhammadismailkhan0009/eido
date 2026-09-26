# For statements

Eido supports classic declaration-condition-update `for` loops.

```eido
for (var i = 0; i < 10; i = i + 1) {
    ...
}
```

## Header

The first version intentionally uses a fixed three-clause form:

1. initializer — a `var` declaration;
2. condition — a `Bool` expression;
3. update — assignment to an existing variable.

All three clauses are required, and the complete header must be parenthesized.

```eido
for (var i = 0; i < 10; i = i + 1) {
    ...
}
```

The initializer runs once. The condition is checked before every iteration.
The update runs after every normally completed iteration.

## Scope

The initializer binding belongs to the entire for loop:

- it is visible to the condition;
- it is visible to the update;
- it is visible to the body;
- it does not leak after the loop.

The body is an isolated nested scope. Locals declared in the body do not become
visible to the update or after the loop.

## Loop control

`break;` exits the nearest enclosing loop immediately.

`continue;` skips the remainder of the current body, then executes the for
update before reevaluating the condition.

```eido
for (var i = 0; i < 5; i = i + 1) {
    if (i == 2) {
        continue;
    }
}
```

Nested for/while loops own their own break/continue targets.

## Return coverage

A for loop never by itself proves that a result function definitely returns,
because its condition may be false before the first iteration.

## Current boundary

This first version does not yet support:

- omitted initializer, condition, or update clauses;
- assignment-only initializers;
- multiple initializer/update expressions;
- `for item in collection`;
- ranges or iterator protocols.

Those features depend on later collection/type-system decisions.
