# Class field access

Eido reads class fields with postfix dot access:

```eido
point.x
employee.address.zip
```

Field access is an expression and may participate anywhere its resulting type
is valid:

```eido
return point.x + 2;
```

It may also read directly from a fresh construction:

```eido
return Point { x: 10; }.x;
```

## Resolution

The receiver expression is analyzed first.

Its semantic type must be a nominal class type. The requested field is then
resolved from that class declaration, and the field access expression receives
the field's declared semantic type.

Therefore chained access resolves one hop at a time:

```text
employee
  : Employee
      ↓ .address
  : Address
      ↓ .zip
  : Int
```

The compiler rejects:

- access on primitive values;
- fields not declared by the receiver's nominal class.

## Precedence

Field access is postfix and binds tighter than unary and binary operators.

```eido
point.x + 1
```

means:

```text
(point.x) + 1
```

Access chains associate left to right:

```eido
employee.address.zip
```

means:

```text
(employee.address).zip
```

## Copy/reference boundary

A field may itself have a class type, which is necessary for chaining:

```eido
employee.address.zip
```

However, Eido still has no implicit class copy/reference semantics.

Therefore this is currently rejected:

```eido
var address = employee.address;
```

and so is implicit reassignment from a class-valued field:

```eido
otherAddress = employee.address;
```

Fresh construction remains valid because it does not require choosing whether an
existing class value is copied or aliased.

## Mutation boundary

This feature is read-only field access.

Field mutation such as:

```eido
point.x = 20;
```

is not yet supported and will be designed separately.
