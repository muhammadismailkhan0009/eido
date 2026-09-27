# Class construction

Eido constructs nominal class values with a named brace expression:

```eido
var point = Point {
    x = 10;
    y = 20;
};
```

Construction is an expression. Field initialization uses `=`, the same token
used to establish a local's initial value; `:` is not valid construction syntax.
The surrounding statement owns its final semicolon; each field initializer
inside the construction also ends with a semicolon.

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
    y = 20;
    x = 10;
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
    address = Address {
        zip = 54000;
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
    first = 10;
    second = first + 1;
}
```

Field initializers are expressions evaluated from the surrounding lexical
scope, not sequential statements over a partially constructed object.

## Class-valued field identity

When a construction field receives an existing class object, the relationship
must be explicit:

```eido
Order {
    account = ref account;
    snapshot = copy account;
}
```

`ref` preserves the same logical object. `copy` recursively creates a
detached graph while preserving sharing/cycles inside that graph.

Fresh nested construction and detached callable results do not require another
identity marker.

## Representation boundary

The Nim backend currently lowers classes to generated `ref object` types and
uses generated graph copiers for `copy`. Those are backend choices, not a
commitment to GC, RC, heap allocation, or another memory-management model.

Class equality remains outside the current slice. Class-valued own fields may
now be replaced through `set self.field = ...` using the same relationship rule:
fresh/detached values flow directly, while existing objects require explicit
`ref` or `copy`.

## Current boundary

Not yet included:

- interfaces;
- contracts.
