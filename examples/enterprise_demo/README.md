# Enterprise Order Processing Demo

This example is a small enterprise-style order-processing vertical slice rather
than a syntax catalogue. The executable `app` module depends on the `orders`
domain/application module.

## Architecture

The `orders` module explicitly exports only:

- `OrderProcessor` — the architectural processing contract.
- `OrderApplication` — the static application facade used by clients.

`StandardOrderProcessor` is the normal internal implementation. The
`FaultInjection*` classes are deliberately broken internal implementations used
only by the demo scenarios to prove that runtime contracts stop bad behavior at
the expected boundary. They are not exported API.

`Order` and `ProcessingResult` are transitively public because exported API
signatures expose them.

## Contract behavior demonstrated

### `require` — legal invocation domain

Normal processing accepts only a pending order and the supported actions:

```eido
require {
    order.isPending();
    action == "approve" or action == "reject";
}
```

`order.isPending()` is an observational helper. The compiler infers that it is
contract-safe; no `pure` annotation is required.

### `invariant` — continuously valid class state

`Order` continuously guarantees:

```eido
invariant {
    self.reference != "";
    self.customer != "";
    self.amountCents > 0;
    self.status == "PENDING" or
        self.status == "APPROVED" or
        self.status == "REJECTED";
}
```

Construction is checked immediately. Every own-field mutation in an
invariant-bearing class is also checked immediately before the next Eido
statement may execute.

### `ensure` — complete successful post-state

`ensure` is not only about returned values. `Order.approve()` returns nothing,
but still guarantees the state mutation:

```eido
function approve() {
    require {
        self.isPending();
    }

    set self.status = "APPROVED";

    ensure {
        self.status == "APPROVED";
    }
}
```

The fault-injection workflow demonstrates the same rule over a mutated parameter
from a zero-result orchestration method:

```eido
function violateSideEffectPostcondition(Order order) {
    require {
        order.isPending();
    }

    order.reject();

    ensure {
        order.status == "APPROVED";
    }
}
```

The call is valid and the mutation itself preserves `Order`'s invariant, but the
operation's promised post-state is false, so its `ensure` fails.

### Contextual `result`

A value-returning operation can constrain whichever value was selected by any
successful return path:

```eido
ensure {
    result.orderReference == order.reference;
    result.message != "";
}
```

`ProcessingResult.summary()` also has two physical `return` statements governed
by one postcondition:

```eido
ensure {
    result != "";
}
```

`result` is contextual rather than globally reserved. The CLI deliberately uses
an ordinary local with the same name:

```eido
var result = OrderApplication.run(processor, order, scenario);
```

Inside a value-returning `ensure`, contextual `result` shadows any same-named
ordinary binding. Elsewhere, `result` is an ordinary identifier.

## Build

With Eido installed on `PATH`:

```text
cd examples/enterprise_demo
eido check
eido build
```

The executable is written to `build/bin/enterprise_demo`. From a compiler-development checkout, the equivalent local binary invocation is `../../eido ...` from this directory.

## Scenarios

### Normal approval

```text
eido run -- approve "Acme GmbH"
```

Expected:

```text
Processing result: APPROVED | ORD-2026-0001 | Acme GmbH | APPROVED via CLI
Final order: ORD-2026-0001 | Acme GmbH | APPROVED
```

The domain preconditions, construction invariants, immediate mutation invariant,
side-effect postcondition, result postconditions, and method-exit invariant all
succeed.

### Normal rejection

```text
eido run -- reject "Acme GmbH"
```

Expected final state is `REJECTED`, with all contracts satisfied.

### Precondition failure

```text
eido run -- require-failure "Acme GmbH"
```

The application deliberately submits unsupported action `ship`. Expected
failure:

```text
require contract failed in method 'process'
```

The invalid operation never enters the processor body.

### Invariant failure

```text
eido run -- invariant-failure "Acme GmbH"
```

The demo deliberately constructs an `Order` with status `CORRUPT`. Expected
failure:

```text
invariant contract failed for class 'enterprise_demo.orders.Order'
```

The invalid aggregate never becomes a usable domain object.

### Returned-result postcondition failure

```text
eido run -- ensure-failure "Acme GmbH"
```

An internal fault-injection processor performs a valid approval but returns a
`ProcessingResult` carrying the wrong order reference. It declares no duplicate
postcondition of its own; the inherited `OrderProcessor` interface postcondition
catches the implementation bug:

```text
ensure contract failed in method 'process'
```

This scenario exercises contextual `result`.

### Side-effect postcondition failure with no returned value

```text
eido run -- side-effect-ensure-failure "Acme GmbH"
```

The fault-injection workflow legally changes the order to `REJECTED` but falsely
promises that successful completion leaves it `APPROVED`. The zero-result method
fails with:

```text
ensure contract failed in method 'violateSideEffectPostcondition'
```

This demonstrates that `ensure` constrains arbitrary observable post-state, not
only return values.

## Current runtime diagnostic limitation

Contract enforcement is correct, but failures currently expose generated Nim
stack-frame names before the useful Eido contract message. Replacing those with
source-level Eido contract diagnostics is a separate tooling/runtime improvement.
