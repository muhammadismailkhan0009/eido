# Interfaces

Interfaces are Eido's explicit behavioral contracts. They exist for architectural
boundaries, not as a default abstraction for ordinary same-module collaboration.

## Syntax

```eido
interface PaymentService {
    function pay(Int amount) returns Int;
}

class StripeService implements PaymentService {
    Int multiplier;

    function pay(Int amount) returns Int {
        return amount * self.multiplier;
    }
}
```

One class may implement multiple interfaces:

```eido
class Store implements Readable, Writable {
    ...
}
```

An interface may extend one interface in v0:

```eido
interface Child extends Parent {
    function child() returns Int;
}
```

Multiple interface extension and generic interfaces are deferred.

## Explicit conformance

Conformance is nominal and intentional. Merely having matching methods does not
make a class implement an interface.

Every required interface method, including inherited methods, must:

- exist on the implementing class;
- be an instance method;
- have exactly the same parameter types;
- have exactly the same result cardinality/type.

Because Eido infers static-vs-instance behavior from `self`, a self-free method
is static and therefore cannot satisfy an interface contract.

Extra class methods remain implementation-local and do not affect conformance.

## Interface values and dispatch

Interfaces are real semantic types and may be used as local values, parameters,
and results.

A concrete class value may flow into an interface only when the class explicitly
implements that interface. A child-interface value may flow into an ancestor
interface only through declared `extends`.

```eido
class Payments {
    function service() returns PaymentService {
        return StripeService { multiplier = 1; };
    }
}

function run(PaymentService service) returns Int {
    return service.pay(42);
}
```

Calls through an interface are runtime interface dispatch. HIR marks this
explicitly as interface dispatch rather than treating it as an ordinary class
method call.

Interface values are opaque behavioral handles. The hidden concrete object
identity is preserved by a class-to-interface conversion, but source-level
`copy`/`ref` remain operations on concrete class values, not interface
handles.

## Interface extension

Implementing a child interface also requires every inherited parent contract.

```eido
interface Base {
    function base() returns Int;
}

interface Child extends Base {
    function child() returns Int;
}

class Impl implements Child {
    Int value;

    function base() returns Int {
        return self.value;
    }

    function child() returns Int {
        return self.value + 1;
    }
}
```

A `Child` value may be used where `Base` is expected.

## Architectural ownership

In module projects, interfaces are architectural declarations. An interface must
participate in its owning module architecture through either:

- `exports`, or
- a parent-owned `provides` contract.

Interfaces are closed to their owning module family by default. A class may
implement, and an interface may extend, a contract only inside the module that
owns the interface or one of that module's descendants.

There is no implicit external/plugin implementation permission in v0. If Eido
later needs open extension contracts, that will require an explicit opt-in
design rather than weakening closed interfaces globally.

Example:

```yaml
module: payments

sources:
  - PaymentService.eido
  - Payments.eido

children:
  processor:
    path: processor

exports:
  - PaymentService
  - Payments

provides:
  PaymentService:
    by: processor
```

The compiler verifies that:

- `PaymentService` is an interface owned by `payments`;
- `processor` is a descendant provider;
- the provider subtree contains a class that explicitly implements
  `PaymentService` (or a child interface that extends it);
- unrelated modules cannot implement the closed contract.

## Boundary type restrictions

Concrete behavioral class types are never part of an interface contract.

Therefore interface parameters/results may currently use:

- primitives;
- String;
- interfaces;
- optional forms when otherwise legal.

Concrete class parameters/results in interface signatures are rejected.

API data types are the next missing boundary feature. Once Eido has a distinct
data-type model, public interface signatures will be allowed to carry those
types and module API closure can expose them transitively without leaking
behavioral implementation classes.

## Backend representation

The Nim backend currently lowers an interface value to a generated wrapper whose
contract methods are closure fields. A class-to-interface adapter captures the
hidden concrete instance; interface-extension upcasts preserve the bound
closures.

This is a backend implementation detail, not Eido's semantic representation.
Other backends may use vtables, fat pointers, tagged handles, or another
equivalent representation while preserving the same interface semantics.
