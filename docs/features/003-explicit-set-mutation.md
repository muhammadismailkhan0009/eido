# Feature 003 — Explicit set mutation

Status: approved and implemented.

Eido separates initialization from mutation:

```eido
var salary = 5000;
set salary = salary + 500;
set salary = 6000;
```

The source-language rule is:

```text
=       establish an initial value
set     mutate existing state
```

Bare reassignment such as `salary = 6000;` is not valid Eido syntax.

## Local mutation

A `var` binding may be mutated with a semicolon-terminated `set` statement:

```eido
var value = 5;
set value = value + 1;
```

The target must already exist. Parameters cannot be mutated.

Primitive locals may receive any type-compatible expression, including another
existing primitive local:

```eido
var first = 5;
var second = 10;
set second = first;
```

Class-valued locals remain representation-neutral. They may be rebound from a
fresh construction or detached callable result:

```eido
var marker = Marker {};
set marker = Marker {};
```

Setting from an existing class object remains rejected. `copy` and `ref`
belong to new local-binding or construction-field relationships and are not
legal `set` operands.

## Own-field mutation

Inside a class method, an own primitive field may be mutated only through the
explicit current receiver `self`:

```eido
class Account {
    Int balance;

    function withdraw(Int amount) returns Int {
        set self.balance = self.balance - amount;
        return self.balance;
    }
}
```

This works because `self` denotes the method's current class receiver and the
method owns that receiver's state transition. Unqualified own-field mutation is
rejected.

Parameters remain immutable, and class-valued fields are not yet mutable.

External field mutation is not part of the grammar:

```eido
set account.balance = 0; // invalid
```

## For-loop updates

Classic for-loop updates use the same mutation construct:

```eido
for (var i = 0; i < 10; set i = i + 1) {
    ...
}
```

There is no separate assignment syntax for loop headers.
