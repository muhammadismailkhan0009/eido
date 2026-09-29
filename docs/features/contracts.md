# Design by Contract

Eido v0 supports three optional declaration-level contract sections:

```eido
class Account {
    Int balance;

    invariant {
        self.balance >= 0;
    }

    function debit(Int amount) {
        require {
            amount > 0;
            amount <= self.balance;
        }

        set self.balance = self.balance - amount;

        ensure {
            self.balance >= 0;
        }
    }
}
```

`require` narrows the legal invocation domain, `ensure` states conditions that
must hold after successful callable execution, and `invariant` defines valid
class state. `ensure` describes the complete observable post-state, not only a
returned value: it may constrain mutated `self` fields, observable state reached
through parameters, and the logical returned value when one exists. Contract
sections are optional, unnamed, non-empty, and every clause must have type
`Bool`. `require` appears before executable function statements, `ensure` is the
final function section, and a class may declare at most one `invariant` section.

Contracts are compiler-owned semantic data rather than ordinary statements.
They survive into HIR and are available to tooling. v0 lowers them to
always-enabled runtime safety checks. `ensure` runs only on normal callable
exit, after a return expression has been evaluated; abnormal runtime failure
does not execute or replace the original failure with a postcondition check.

Class invariants are continuously enforced at the language's class-state
mutation boundaries. They are checked after construction, on every instance
method entry and normal exit (including nested calls on the same object), and
immediately after every `set self.field = ...`. A mutation that violates an
invariant therefore fails before the next Eido statement executes; methods may
not temporarily break an invariant and repair it later.

Invariant evaluation has one narrowly scoped recursion guard. While the
invariant checker itself is evaluating, observational instance helpers such as
`self.valid()` do not recursively start another invariant check. Ordinary nested
method calls do not activate this guard and remain fully checked. The guard is a
backend detail and is not visible in Eido class state.

Eido v0 deliberately does not define `old`, named clauses, `modifies`, purity
syntax, proof syntax, or a source-level contract exception model. Stronger
static verification can later consume the same HIR contract facts without
changing the basic source model.


## Postcondition result binding

Value-returning callables expose contextual `result` only inside `ensure`. Its
type is exactly the callable's declared return type and it denotes the value
produced by whichever successful `return` path was taken. The return expression
is evaluated once, bound to this contextual `result`, then the postcondition is
checked, and only then is the value returned.

```eido
function absolute(Int value) returns Int {
    if (value < 0) {
        return -value;
    }
    return value;

    ensure {
        result >= 0;
    }
}
```

`result` is not a globally reserved keyword. Parameters and locals may be named
`result` normally, and ordinary name resolution applies outside `ensure`. Inside
`ensure` of a value-returning callable, contextual `result` shadows any ordinary
binding of the same name. Inside `ensure` of a zero-result callable, `result` is
invalid even if an outer binding has that name, because that context has no
logical returned value. For class-valued results, ordinary observational member
access is available, for example `ensure { result.value >= 0; }`.


## Interface contracts

Interfaces may attach `require` and `ensure` to method signatures without
providing executable bodies. Those clauses describe the abstraction and are
propagated into concrete implementations rather than replaced by implementation
contracts. Implementations may add their own clauses; inherited and declared
clauses remain separately tracked and are both enforced.

Inside an interface contract, parameters are visible, `result` has its normal
contextual meaning in value-returning `ensure`, and `self` represents the
interface abstraction. Calls such as `self.available()` are legal when the method
is visible on the interface. When an implementation is analyzed, such inherited
calls are rebound to the concrete methods and must satisfy the normal
compiler-inferred observational-safety rules. Ordinary dynamic dispatch through
an arbitrary interface-valued variable remains contract-unsafe in v0.

## Contract-safe calls

Contract expressions are observational. Ordinary Eido callables remain free to
mutate state, but a callable used from `require`, `ensure`, or `invariant` must
be inferred contract-safe by the compiler. Safety is transitive across the
resolved call graph: direct own-field mutation makes a method unsafe, and any
callable that reaches an unsafe callable is unsafe as well. Local-variable
`set` does not count as an observable effect.

No `pure` annotation is required or available. Native calls are rejected from
contracts because their effects cannot currently be verified. Dynamic interface
dispatch is also rejected from contracts because the concrete implementation's
effects cannot be proven at the call site. These restrictions apply only in
contract expressions; the same effectful callables remain legal in ordinary
executable code.
