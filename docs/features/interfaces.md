# Interfaces

Interfaces are Eido's explicit behavioral contracts. They exist for architectural
boundaries, not as a default abstraction for ordinary same-module collaboration.

## Syntax

```eido
interface PaymentService {
    function pay(Int amount) returns Int {
        require {
            amount > 0;
        }

        ensure {
            result >= 0;
        }
    }
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

An interface may declare **any number of type parameters** and classes may
implement matching applications:

```eido
interface Pair<Left, Right> {
    function first() returns Left;
    function second() returns Right;
}

class PairBox<A, B> implements Pair<A, B> {
    A firstValue;
    B secondValue;

    function first() returns A { return self.firstValue; }
    function second() returns B { return self.secondValue; }
}
```

Used applications such as `Pair<Int, Bool>` are statically specialized into
ordinary concrete interface declarations before semantic analysis and runtime
dispatch. Every type argument is explicit; raw generic uses and wrong-arity
applications are rejected. Different applications are distinct nominal
interface types, and each application is materialized only once.

Method `require`/`ensure` clauses are specialized alongside parameter and
result types, preserving their normal runtime enforcement. A class may
implement a specialized interface through its ordinary instance methods;
there is no special requirement for static classes.

An interface may extend one non-generic interface in the current slice:

```eido
interface Child extends Parent {
    function child() returns Int;
}
```

Generic interface inheritance and multiple-interface extension are deferred.


## Behavioral contracts

Interface methods may be signature-only or may declare `require` and `ensure`
sections. The contract block is not an executable method body: statements,
mutation, control flow, and `return` are not legal there.

```eido
interface AccountService {
    function available() returns Int;

    function withdraw(Int amount) returns Int {
        require {
            amount > 0;
            amount <= self.available();
        }

        ensure {
            result >= 0;
        }
    }
}
```

Interface contract scope contains the method parameters, contextual `result` in
a value-returning `ensure`, and `self` as the interface abstraction. `self` may
therefore call methods visible on that interface (including inherited methods),
but interface contracts cannot inspect concrete implementation fields or call
implementation-only methods. Ordinary top-level functions are not part of the
interface contract scope.

Interface contracts propagate into every concrete implementation. They are not
replaced when the class declares its own contracts: inherited and class-declared
clauses remain distinct semantic obligations and both execute at the concrete
method boundary. This is true for calls through an interface value and for calls
directly through the concrete class. Interface parameter names need not match
implementation parameter names; inherited clauses bind parameters by signature
position.

An implementation may declare additional `require`/`ensure` clauses. Static
compatibility reasoning between inherited and implementation-declared clauses is
a separate verification layer; this section defines propagation/ownership rather
than the proof algorithm.

Contract calls through interface `self` must remain observational in each
implementation. Eido rebinds inherited clauses to the concrete method and applies
the existing compiler-inferred contract-safety analysis, so an effectful helper
implementation cannot satisfy an interface contract that observes that helper.

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

Implementing a child interface also requires every inherited parent method and
behavioral contract. A child may redeclare an inherited method only with the same
callable signature; its own contract clauses are additional obligations and the
parent clauses remain inherited.

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


## Multiple interfaces and method identity

A class may implement multiple interfaces when their required methods are
distinct. Two independently declared interface methods with the same method name
cannot be implemented by one class, even if their signatures happen to match.
This avoids silently combining unrelated behavioral abstractions.

The exception is one declaration inherited through multiple paths. If `Left` and
`Right` both inherit `Base.value` without redeclaring it, a class may implement
`Left, Right`; both paths refer to the same original method declaration. If a
child redeclares that method, it becomes a distinct effective declaration for
this ambiguity rule.

## Architectural ownership

In module projects, interfaces are architectural declarations. An interface must
participate in an exported, adopted, or provided API surface. That participation
may be direct or may arise transitively because a reachable public class
implements the interface or another reachable interface extends/references it.

Interfaces are closed to their owning module family by default. A class may
implement a contract within its owner or descendants, or externally when the
owner explicitly lists the interface in both `exports` and
`allowsExternalImplementation` in `module.yaml`. Transitive API visibility
alone does not grant eligibility. The permission is optional, owner-local, and applies only to
`implements`, not `extends`. Every ancestor contract must independently
authorize the implementing module. Re-exports cannot grant permission on
behalf of another owner, and normal dependency, visibility, conformance and
contract enforcement rules still apply. See [modules](modules.md) for the
manifest rules. Interface extension remains closed to the owning family.

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

## Boundary type reachability

Interface signatures may use ordinary classes directly:

```eido
interface PaymentService {
    function pay(PaymentRequest request) returns PaymentResult;
}
```

When such an interface participates in a module API, the referenced classes
become part of that module's transitive API closure. Those classes remain normal
classes with their existing fields, construction rules, methods, identity, and
implemented interfaces; Eido does not convert them into DTO/data projections.

This reachability continues recursively through the exposed classes' own fields,
method signatures, and implemented interfaces. The developer controls the
architectural consequence by choosing the exported API roots rather than by
classifying object kinds.

## Backend representation

The Nim backend currently lowers an interface value to a generated wrapper whose
contract methods are closure fields. A class-to-interface adapter captures the
hidden concrete instance; interface-extension upcasts preserve the bound
closures.

This is a backend implementation detail, not Eido's semantic representation.
Other backends may use vtables, fat pointers, tagged handles, or another
equivalent representation while preserving the same interface semantics.
