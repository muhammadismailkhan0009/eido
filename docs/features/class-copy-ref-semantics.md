# Class copy/ref and callable identity semantics

Status: approved and implemented.

Eido makes persistent class identity decisions explicit without exposing the
backend memory model.

## Existing object bindings

A bare existing class value cannot initialize another persistent local:

```eido
var account = Account { balance: 100; };
var other = account; // invalid
```

The new binding must state its relationship:

```eido
var alias = ref account;
var detached = copy account;
```

`ref` preserves the same logical object identity. `copy` creates a new,
detached class graph containing the same field state.

`copy` recursively detaches reachable class-valued fields while preserving
sharing/cycles inside the copied graph.
## Construction fields

Existing class values used to establish a class-valued field relationship also
require an explicit decision:

```eido
var order = Order {
    account: ref account;
    snapshot: copy account;
};
```

Fresh construction and detached callable results do not need another
`copy`/`ref` marker.

## Parameters

Class-valued function and method parameters preserve the caller's logical object
identity for the call:

```eido
function charge(Account account, Int amount) {
    account.withdraw(amount);
}
```

The parameter binding itself is immutable. Direct external field mutation is
still invalid; state changes occur only when the class's own method executes
`set self.field = ...`.
## Class-valued returns

A class-valued return must represent fresh/detached identity.

Valid examples include fresh construction and a detached local:

```eido
function snapshot(Account account) returns Account {
    var result = copy account;
    return result;
}
```

Returning existing identity is rejected:

```eido
return account;      // parameter identity: invalid
return self;         // current receiver: invalid
return self.account; // existing field identity: invalid
```

`copy` and `ref` are not return modifiers and cannot be written directly in
a return statement. They are also not parameter modifiers or callable-result
modifiers. They are relationship markers at persistent class boundaries:
new local bindings, construction fields, class-local rebinding, and own
class-field replacement.
A class-valued function/method call is already guaranteed to return detached
identity, so its result may initialize a local directly:

```eido
var snapshot = account.snapshot();
```

Wrapping a call result in `copy` or `ref` is invalid.

## Relationship replacement with set

Class-valued `set` uses the same explicit relationship rule as initialization.
Fresh construction and detached callable results flow directly:

```eido
set current = Account { balance: 0; };
set current = createAccount();
```

Existing class objects require an explicit choice:

```eido
set current = ref other;
set current = copy other;
set self.account = ref other;
set self.account = copy other;
```

Bare existing-object replacement is rejected. A `ref` rebinding changes the
local's provenance to existing identity; a `copy` rebinding changes it to
detached identity, which also affects whether that local may be returned from
a class-valued function.

## Mutation before copying

Mutation and detachment remain ordered, explicit operations:

```eido
function modify(Account account) returns Account {
    account.withdraw(100);
    var modified = copy account;
    return modified;
}
```

The caller's Account is mutated first; the returned Account is then detached
from that updated state. Copying first and mutating the copy has different,
visibly different source code.

## Memory-model boundary

These are logical identity semantics, not allocation semantics. The language
still does not commit classes to GC, RC, stack, heap, regions, or another
memory-management strategy.
