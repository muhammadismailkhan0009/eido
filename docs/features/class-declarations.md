# Class declarations

Eido's first class slice introduces nominal class declarations with fields only.

```eido
class Point {
    Int x;
    Int y;
}
```

## Syntax

Class bodies use the compiler's existing statement/declaration termination rules:

- fields are written as `Type name;`;
- each field declaration ends with `;`;
- the closing `}` ends the class declaration;
- no comma or semicolon follows the class block.

An empty class is valid:

```eido
class Marker {
}
```

## Nominal types

Every class declaration registers one nominal semantic type.

```eido
class Address {
    Int zip;
}

class Employee {
    Address address;
}
```

`Address` in the Employee field resolves to the declared Address class type,
not merely to a matching structural shape.

All class names are collected before field types are resolved, so forward
references are valid.

```eido
class Employee {
    Address address;
}

class Address {
    Int zip;
}
```

Duplicate class names, duplicate field names within one class, and unknown field
types are rejected.

## Representation boundary

This slice deliberately does not define class allocation or ownership semantics.

A semantic class type does not yet mean:

- heap allocation;
- reference identity;
- garbage collection;
- value-copy semantics;
- pointer semantics.

The semantic type model records nominal identity independently of those later
decisions.

## Construction

Named construction is now supported with `Type { field: expression; }`.
See `class-construction.md` for exact-field, nesting, scope, and representation rules.

## Current boundary

Not yet included:

- field mutation;
- methods;
- class types in function signatures;
- interfaces or contracts.
