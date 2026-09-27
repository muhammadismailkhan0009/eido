# Class declarations

Eido class declarations define nominal fields and may also contain instance methods.

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

The language now defines logical class-identity flow (`ref` preserves identity;
`copy` creates detached identity), but it still deliberately does not define
allocation, lifetime, or reclamation semantics.

A semantic class type therefore does not imply:

- heap allocation;
- garbage collection;
- reference counting;
- pointer representation;
- any particular ownership/reclamation strategy.

The semantic type model records nominal identity independently of those backend
and memory-management decisions.

## Construction

Named construction is now supported with `Type { field = expression; }`.
See `class-construction.md` for exact-field, nesting, scope, and representation rules.

## Current boundary

Class-valued own-field replacement through `set self.field = ...` is now part
of the class model: fresh/detached values flow directly and existing objects
require explicit `ref` or `copy`.

Still outside the current class slice:

- interfaces;
- contracts.

Nominal class types in fields, function/method signatures, construction,
relationship mutation, copy/ref identity flow, and detached returns are implemented.
