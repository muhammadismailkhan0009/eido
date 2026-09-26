# Class construction

Eido constructs nominal class values with a named brace expression:

```eido
var point = Point {
    x: 10;
    y: 20;
};
```

Construction is an expression. The surrounding statement owns its final
semicolon; each field initializer inside the construction also ends with a
semicolon.

## Field rules

Every declared field must be supplied exactly once.

```eido
class Point {
    Int x;
    Int y;
}
```

Valid:

```eido
Point {
    y: 20;
    x: 10;
}
```

Field order is not semantically significant.

The compiler rejects:

- missing fields;
- unknown fields;
- duplicate fields;
- initializer expressions whose type does not match the declared field type.

## Nested and empty construction

Construction composes recursively:

```eido
Employee {
    address: Address {
        zip: 54000;
    };
}
```

A zero-field class is constructed with:

```eido
Marker {}
```

## Initializer scope

Construction entries do not introduce field names into an initializer scope.

This is invalid unless an outer local named `first` already exists:

```eido
Pair {
    first: 10;
    second: first + 1;
}
```

Field initializers are expressions evaluated from the surrounding lexical
scope, not sequential statements over a partially constructed object.

## Representation boundary

The Nim backend currently lowers classes to generated `ref object` types.
That is an internal backend representation, not an Eido semantic commitment.

Eido still does not define:

- class reference identity;
- implicit class copying;
- class equality;
- bare class-to-class reassignment semantics;
- garbage-collection or ownership semantics.

Bare class identifier reassignment remains rejected until explicit copy/ref
semantics are designed.

## Current boundary

Not yet included:

- field mutation;
- class-valued function parameters/results;
- methods;
- interfaces;
- contracts.
