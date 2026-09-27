# Class instance methods

Eido classes may own instance methods using the existing `function` syntax:

```eido
class Account {
    Int balance;

    function remaining(Int amount) returns Int {
        return self.balance - amount;
    }
}
```

Methods are class-owned behavior. Inside an instance method, reserved `self`
explicitly denotes the current instance.

## Current-instance access

Own fields must be accessed through `self`:

```eido
return self.balance - amount;
```

Own methods are called the same way:

```eido
return self.remaining(20);
```

Unqualified own-field access is rejected. An unqualified call such as
`calculate(...)` remains a top-level function call rather than an implicit
method lookup.

The compiler lowers `self` to a hidden receiver parameter internally; that
backend representation is not exposed as a separate Eido value declaration.

## Method calls

Instance methods are called through a class-valued receiver:

```eido
var account = Account {
    balance: 100;
};

var remaining = account.remaining(20);
```

Zero-result methods may be called as statements:

```eido
marker.inspect();
```

Method lookup is nominal:

1. analyze the receiver expression;
2. require its type to be a declared class;
3. resolve the method from that class;
4. check argument count and types;
5. use the method's declared result type.

Method signatures are collected before method bodies, so calls are independent
of source declaration order.

## Method body behavior

Method bodies reuse the existing function/statement semantics:

- parameters;
- local variables;
- returns;
- arithmetic and Boolean expressions;
- conditionals;
- loops and loop control;
- top-level function calls;
- `self.method(...)` calls on the current instance;
- `set` mutation of locals;
- `set self.field = ...` mutation of own primitive fields.

Method parameters/results may use primitive or declared nominal class types.
Class parameters preserve caller identity for the call, while class-valued
returns must be fresh/detached.

## Name uniqueness

Within one method's effective namespace, class fields, method parameters, and
method locals may not shadow one another.

The enforced rules are:

```text
class field ↔ method parameter    no collision
class field ↔ method local        no collision
parameter ↔ local                 no collision
local ↔ nested local              no shadowing
```

Example:

```eido
class Account {
    Int amount;

    function withdraw(Int amount) returns Int {
        return amount;
    }
}
```

is rejected because the parameter collides with the field.

Different methods have independent parameter/local namespaces, so this remains
valid:

```eido
class Calculator {
    function add(Int left, Int right) returns Int {
        return left + right;
    }

    function subtract(Int left, Int right) returns Int {
        return left - right;
    }
}
```

Method names must be unique within one class in v0; method overloading is not
supported. Different classes may use the same method name.

## Mutation boundary

A method may mutate an own primitive field only through `self`:

```eido
function withdraw(Int amount) returns Int {
    set self.balance = self.balance - amount;
    return self.balance;
}
```

Only class-owned behavior receives this field-mutation authority. External
postfix field mutation such as `set account.balance = 0;` is invalid, and
unqualified `set balance = ...` is rejected.

Class-valued fields remain non-mutable through `set` in the current slice,
even though copy/ref identity semantics are now defined for local bindings and
construction fields.

## Backend representation

The Nim backend lowers each Eido method to a generated procedure whose first
parameter is the hidden receiver. Source-level `self` resolves to that
receiver; the generated parameter remains a backend implementation detail.

## Current boundary

Not yet included:

- class-valued field mutation through `set`;
- method overloading;
- interfaces;
- contracts and invariants.
