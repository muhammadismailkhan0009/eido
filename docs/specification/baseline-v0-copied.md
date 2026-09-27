Yes. At this point it is useful to write a **baseline language specification** before touching the compiler. I’ll distinguish **locked decisions** from things we deliberately have *not* decided, so we don't accidentally encode assumptions into the AST that later become expensive to remove.

For now I will use **Eido** as the internal working codename. It is **not the final public name**; it is simply shorter than constantly saying “our language.” The examples below use `.eido` as a provisional extension.

# Eido v0 — baseline specification

> **Preservation note:** this file intentionally retains earlier v0 design text and examples as historical rationale. Later sections marked **Current implemented v0 semantic addendum** are authoritative where older syntax or semantics conflict with the compiler as it exists now. In particular, current source uses semicolon-terminated statements/declarations, explicit `self` for current-instance access, and the class-identity rules recorded in the addendum.

## 1. Purpose

The original purpose remains the north star:

> **Java-style, predictable enterprise programming compiled ahead-of-time to native code, with a small runtime footprint and substantially less framework/runtime machinery.**

Everything more ambitious—contracts, architectural verification, proofs, data-oriented optimization, automatic parallelism—must remain compatible with that goal.

A normal enterprise operation should remain roughly this simple:

```text
class OrderService {
    repository: OrderRepository,

    function create(request: CreateOrderRequest)
        returns Order
    {
        let order = Order {
            customerId: request.customerId,
            amount: request.amount,
        },

        repository.save(order),

        return order,
    },
},
```

If future language features make ordinary code significantly harder than this, they need very strong justification.

---

# 2. Programming model

The working paradigm is:

> **Statically typed, native, imperative programming with module-oriented architecture and contract-oriented specifications.**

There are effectively two layers:

| Layer | Main constructs | Purpose |
|---|---|---|
| Implementation | `class`, `function`, fields, `let`, `var`, `set`, control flow | Write ordinary software |
| Architecture/specification | `module`, `interface`, `implements`, `extends`, contracts | Define stable boundaries and guarantees |

The language is **not intended to be Java-style inheritance-heavy OOP**.

It uses familiar enterprise syntax while changing some underlying rules.

---

# 3. Locked core declaration constructs

These are currently locked:

```text
module
class
interface
function

implements
extends
```

Their meanings are precise.

### `class`

A `class` is the concrete implementation construct.

It can contain:

```text
fields
methods
state
behavior
```

Example:

```text
class Employee {
    id: EmployeeId,
    salary: Money,

    function increaseSalary(amount: Money) {
        set salary = salary + amount,
    },

    function annualSalary() returns Money {
        return salary * 12,
    },
},
```

A class **may also have zero fields**.

Therefore this remains legal:

```text
class FraudPolicy {
    function evaluate(transaction: Transaction)
        returns Decision
    {
        ...
    },
},
```

So `class` does not mean “must contain mutable data.”

It means:

> **named concrete implementation/type containing data and/or coherent behavior.**

---

# 4. No class inheritance

Locked:

```text
class B extends A
```

is **not supported**.

We are deliberately avoiding implementation inheritance.

Implementation reuse should primarily come from:

```text
composition
functions
contained values
generic algorithms
multiple interface implementation
```

So:

```text
class PayrollService {
    employees: EmployeeStore,
    tax: TaxSystem,
},
```

rather than building class inheritance trees.

---

# 5. Interfaces

An `interface` is **not an ordinary internal abstraction mechanism**.

It means:

> **A named behavioral specification exposed across a module boundary.**

Example:

```text
interface Salary {
    function value() returns Money,
},
```

A module may have its own implementation:

```text
class SeniorSalary implements Salary {
    amount: Money,

    function value() returns Money {
        return amount,
    },

    function increase(amount: Money) {
        set amount = amount + amount,
    },
},
```

Notice:

```text
increase()
```

does not need to appear in `Salary`.

It is local implementation behavior.

Only the behavior intentionally exposed across the module boundary belongs to the interface.

---

# 6. Private/internal interfaces are forbidden

Locked architectural rule:

```text
private interface Foo
```

does not exist.

If an abstraction exists only inside one module, use:

```text
class
function
generic/static behavior
composition
```

instead.

This intentionally eliminates patterns such as:

```text
UserService
UserServiceImpl

OrderService
OrderServiceImpl

FooManager
FooManagerImpl
```

when the abstraction has no genuine module-boundary purpose.

An interface must justify itself by being part of the module's externally meaningful specification.

---

# 7. Interfaces can be implemented internally or externally

Both cases are valid.

### Module-provided API

```text
salary module

Salary interface
     ↑
SeniorSalary
JuniorSalary
```

The module defines the specification and supplies implementations.

### Extension/plugin API

```text
web module

HttpServer interface
       ↑
       │
FastServer from another module
```

The defining module owns the specification, but another module implements it.

The governing rule is:

> **The interface belongs to the module that owns the specification, not necessarily the module that implements it.**

---

# 8. Multiple implementations

Multiple classes may implement the same interface:

```text
class ArrayList<T> implements List<T> {
    ...
},

class LinkedList<T> implements List<T> {
    ...
},
```

And one class may implement multiple interfaces:

```text
class PostgresStore
    implements UserStore, OrderStore, HealthCheck
{
    ...
},
```

This is implementation composition, not inheritance.

---

# 9. Interface extension

Locked keyword:

```text
extends
```

Interfaces **may extend interfaces**.

Example:

```text
interface List<T> {
    function size() returns Int,
    function get(index: Int) returns T,
},

interface MutableList<T> extends List<T> {
    function add(value: T),
},
```

Therefore:

```text
class ArrayList<T> implements MutableList<T>
```

automatically means that `ArrayList<T>` must satisfy:

```text
MutableList<T>
+
List<T>
```

It should **not** need:

```text
implements MutableList<T>, List<T>
```

because that would be redundant.

This is specification extension/subtyping, **not implementation inheritance**.

We can describe the concept internally as *interface refinement*, but `refine`/`refines` is **not a language keyword**.

The syntax is `extends`.

---

# 10. Interface implementation is explicit

We are not using Go-style accidental structural conformance.

This:

```text
class FastServer implements HttpServer
```

is an intentional architectural statement.

The compiler checks it.

Merely having functions with matching names does not silently make a class an `HttpServer`.

This follows our principle:

> **Infer mechanics; require architectural intent explicitly.**

---

# 11. No runtime interface dispatch in v0

For v0, interfaces are primarily **compile-time specifications**.

We are not initially implementing Java-style runtime interface objects.

Therefore:

```text
HttpServer
```

should not automatically imply:

```text
vtable
runtime method lookup
dynamic interface object
```

Where the concrete implementation is known during composition:

```text
HttpServer
    ↓
FastServer
```

the compiler eventually lowers:

```text
server.start()
```

to a direct call equivalent to:

```text
FastServer_start(...)
```

Dynamic dispatch may be reconsidered later if actual use cases justify it.

It is **not part of v0**.

---

# 12. Static polymorphism

Interfaces and generics are intended primarily for compile-time polymorphism.

Conceptually:

```text
function first(values: List<T>) returns T {
    return values.get(0),
},
```

used with:

```text
ArrayList<Int>
LinkedList<Int>
```

can be specialized during compilation.

Conceptually:

```text
first<ArrayList<Int>>
first<LinkedList<Int>>
```

rather than requiring runtime dispatch.

Exactly how aggressively we monomorphize will be an implementation decision, but **runtime interface dispatch is not required by the semantic model**.

---

# 13. Variables and mutation

Locked vocabulary:

```text
let
var
set
```

Intended semantics:

```text
let x = 10,
```

creates an immutable binding.

```text
var x = 10,
```

creates a mutable binding.

Mutation is explicit:

```text
set x = 20,
```

and field mutation:

```text
set employee.salary = newSalary,
```

This gives mutation high visibility.

---

# 14. Control flow

Current v0 control-flow vocabulary:

```text
if
else
for
while
return
```

The implementation model remains imperative and familiar.

We are **not** making logic programming, Prolog-style backtracking, dataflow execution, or declarative querying the default execution semantics.

Those ideas can be revisited later without changing the v0 imperative foundation.

---

# 15. Braces and comma termination

Locked syntax style:

```text
{ ... }
```

for blocks.

Commas are the statement/declaration separator/terminator style we've chosen.

Example:

```text
function max(a: Int, b: Int) returns Int {
    if a > b {
        return a,
    },

    return b,
},
```

and:

```text
class Point {
    x: Float,
    y: Float,

    function length() returns Float {
        return sqrt(x * x + y * y),
    },
},
```

The parser should therefore treat commas as genuine grammar rather than a formatter preference.

---

# 16. Function syntax

Canonical current form:

```text
function name(
    parameter: Type,
) returns ReturnType {
    ...
},
```

No-return functions may omit `returns`.

Example:

```text
function printEmployee(employee: Employee) {
    print(employee.name),
},
```

Functions may occur as class methods.

File-level functions are also part of the intended model because stateless procedural behavior should not require creation of a utility class.

---

# 17. Construction

The examples we've consistently used imply record-like construction:

```text
let employee = Employee {
    id: id,
    salary: salary,
},
```

rather than requiring:

```text
new Employee(...)
```

`new` is therefore **not part of the current v0 keyword set**.

Constructor/lifecycle semantics beyond basic initialization are deliberately deferred.

---

# 18. Contracts

Locked conceptual features:

```text
require
ensure
invariant
old
```

Named contract clauses are also part of the design.

Example:

```text
class Account {
    balance: Money,

    invariant {
        non_negative:
            balance >= 0,
    },

    function withdraw(amount: Money) {
        require {
            positive:
                amount > 0,

            sufficient:
                amount <= balance,
        },

        set self.balance = self.balance - amount,

        ensure {
            decreased:
                balance == old balance - amount,
        },
    },
},
```

The exact internal representation will distinguish:

```text
preconditions
postconditions
type/class invariants
old-state expressions
```

even if syntax later changes.

### v0 behavior

v0 does **not** need SMT proving.

Initially the compiler can:

```text
parse contracts
type-check contracts
validate legal references
lower them to runtime checks
```

Formal verification comes later.

That prevents the proof system from blocking development of the actual language.

---

# 19. Ultimate contract model

Later:

```text
require
ensure
invariant
```

should be convertible into **verification conditions**.

Example:

```text
old_balance >= 0
amount > 0
amount <= old_balance

new_balance = old_balance - amount
```

compiler generates:

```text
prove new_balance >= 0
```

Then an automated solver can discharge straightforward obligations.

Eventually we may add explicit proof facilities, but ordinary application programmers should normally write **contracts, not theorem-prover programs**.

---

# 20. Module model

This needs to be recorded carefully because I previously misunderstood it.

A module is **not**:

```text
module payroll {
    // source code here
}
```

We are not putting program declarations inside a lexical module block.

Instead:

> **A module is a logical architectural grouping of source files defined by `module.lang`.**

Directory structure is optional.

Conceptually:

```text
module.lang
    ↓
declares module payroll
    ↓
owns:
    Employee.eido
    Salary.eido
    PayrollService.eido
```

Files may physically be:

```text
src/Employee.eido
src/Salary.eido
src/PayrollService.eido
```

or arranged into directories.

The filesystem hierarchy does **not** define architectural boundaries.

`module.lang` does.

This is intentionally closer to a logical-modularity system such as the architectural idea behind Spring Modulith.

---

# 21. `module.lang` responsibilities

The module manifest will eventually describe at least:

| Responsibility | v0 intent |
|---|---|
| Module identity | Yes |
| Explicit source-file membership | Yes |
| Exposed declarations | Yes |
| Module dependencies | Yes |
| Interface ownership | Yes |
| Implementation/provider relationships | Later in v0 / early post-v0 |
| Architecture constraints | Later |
| Versioning/API compatibility | Later |

**The exact `module.lang` textual grammar has not previously been locked.**

We should not pretend otherwise.

When we implement modules, we should design that small manifest grammar explicitly rather than accidentally deriving it from example syntax.

That is one of the few syntax items still genuinely open.

---

# 22. Visibility model

The architectural rule we've established is:

```text
interfaces
    → module-boundary specifications
    → cannot be private

ordinary classes/functions
    → may remain module implementation details
    → may be exposed deliberately
```

Therefore we do **not** need to rush into Java-style:

```text
public
protected
private
package-private
```

for v0.

Visibility can initially be module-oriented and controlled through the module definition.

This is more consistent with the architecture we're building.

---

# 23. Data orientation

v0 is **not** introducing a separate `object`, `struct`, or `data` declaration.

We locked:

```text
class
```

The compiler should nevertheless avoid assuming Java-style heavyweight object semantics.

A class is fundamentally:

```text
nominal data representation
+
associated operations
```

For example:

```text
class Employee {
    id: Int,
    salary: Money,
},
```

might eventually lower approximately to:

```c
typedef struct {
    int64_t id;
    Money salary;
} Employee;
```

A method:

```text
employee.raise(amount)
```

might lower roughly to:

```c
Employee_raise(&employee, amount);
```

So `class` does **not** inherently mean:

```text
heap allocation
GC object
runtime identity
virtual dispatch
```

Those are separate semantic decisions.

---

# 24. Native compilation model

Primary compilation path:

```text
.eido source
    ↓
lexer
    ↓
parser
    ↓
AST
    ↓
semantic analysis
    ↓
HIR
    ↓
MIR
    ↓
C backend
    ↓
portable C
    ↓
Clang / GCC
    ↓
native executable
```

We do **not** initially generate:

```text
x86
ARM
RISC-V
```

ourselves.

The C compiler handles:

```text
instruction selection
register allocation
CPU optimizations
object files
machine code
```

Our compiler handles **our language**.

---

# 25. Reference compiler implementation language

Locked current implementation strategy:

> **The reference compiler stays written in Nim.**

There is no requirement to self-host.

That gives us:

```text
fast compiler development
easy AST structures
good native performance
C interoperability
ability to compile the compiler itself through Nim's C backend
potential JS build of compiler-core later
```

The language may eventually self-host as an experiment, but the Nim compiler can remain authoritative indefinitely.

---

# 26. JavaScript target

Ultimate target architecture:

```text
                     MIR
                    /   \
                   /     \
             C backend   JS backend
                 ↓           ↓
             native       JavaScript
```

Important distinction:

> Nim supporting JavaScript does **not** automatically give Eido a JavaScript backend.

We still implement:

```text
Eido MIR → JavaScript
```

ourselves.

However, keeping compiler-core portable Nim also potentially allows:

```text
compiler-core.nim
    ↓
Nim JS backend
    ↓
browser compiler/tooling
```

later.

---

# 27. AST strategy

Locked:

> **Our AST is written ourselves in Nim.**

Tree-sitter is not the compiler AST.

Initial frontend:

```text
source
 ↓
handwritten lexer
 ↓
tokens
 ↓
handwritten parser
 ↓
our AST
```

Parser strategy:

```text
recursive descent
    declarations/statements

Pratt parser
    expressions/operators
```

Tree-sitter may be introduced later for:

```text
editor syntax parsing
incremental parsing
highlighting
structural navigation
```

but it is not required for the compiler frontend.

---

# 28. Compiler internal representations

We should **not** compile directly:

```text
AST → C
```

because that will make JS and later verification painful.

The intended layers are:

```text
AST
 ↓
HIR
 ↓
MIR
 ↓
backend
```

### AST

Close to source syntax.

Example:

```text
MethodCall
    target: employee
    method: increaseSalary
    args: ...
```

### HIR

Semantically resolved.

It knows:

```text
symbol IDs
resolved types
resolved methods
interface relationships
module ownership
generic parameters
contract information
```

Example:

```text
ResolvedCall
    function = Employee.increaseSalary
    receiverType = Employee
    argType = Money
```

### MIR

Backend-friendly.

Most high-level constructs should already be gone.

For example:

```text
call Employee_increaseSalary(
    address_of employee,
    amount
)
```

Interfaces should ideally have been resolved/specialized before or during lowering into MIR when static binding is possible.

---

# 29. Compiler project structure

I would start with this structure:

```text
compiler/
│
├── src/
│   ├── eido.nim
│   │
│   ├── frontend/
│   │   ├── source.nim
│   │   ├── token.nim
│   │   ├── lexer.nim
│   │   ├── ast.nim
│   │   └── parser.nim
│   │
│   ├── sema/
│   │   ├── symbols.nim
│   │   ├── scopes.nim
│   │   ├── types.nim
│   │   ├── resolve.nim
│   │   ├── interfaces.nim
│   │   ├── contracts.nim
│   │   └── check.nim
│   │
│   ├── modules/
│   │   ├── manifest.nim
│   │   ├── graph.nim
│   │   └── visibility.nim
│   │
│   ├── ir/
│   │   ├── hir.nim
│   │   ├── lower_hir.nim
│   │   ├── mir.nim
│   │   └── lower_mir.nim
│   │
│   ├── backend/
│   │   ├── c.nim
│   │   └── js.nim
│   │
│   ├── runtime/
│   │   └── runtime.nim
│   │
│   └── diagnostics/
│       ├── diagnostic.nim
│       └── render.nim
│
└── tests/
```

`js.nim` can initially exist as a placeholder; we should build the C backend first.

---

# 30. Compilation phases

The implementation sequence should be:

1. **Lexer** — characters → tokens.
2. **Parser** — tokens → AST.
3. **AST dump** — verify grammar before semantics.
4. **Name resolution** — determine what identifiers refer to.
5. **Primitive type checking**.
6. **Functions and calls**.
7. **Classes, fields and methods**.
8. **Interfaces + `implements`**.
9. **Interface `extends`**.
10. **Generics/static specialization**.
11. **Contracts**.
12. **`module.lang` and cross-file/module semantics**.
13. **HIR**.
14. **MIR**.
15. **C emission**.
16. **Compile generated C and execute acceptance tests**.
17. **Standard library/runtime foundation**.
18. **JavaScript backend later**.

We should resist implementing all sixteen pieces simultaneously.

---

# 31. Initial primitive language subset

The very first compiler slice should be much smaller than the entire v0 spec.

Something like:

```text
Int
Bool

let
var
set

function
return

+
-
*
/
==
<
>

if
else
```

Enough to compile:

```text
function add(a: Int, b: Int) returns Int {
    return a + b,
},

function main() returns Int {
    let x = add(10, 20),

    return x,
},
```

First milestone:

```text
source
→ tokens
→ AST
```

Second:

```text
AST
→ type checked AST/HIR
```

Third:

```text
HIR/MIR
→ C
→ executable
```

Only after that should `class` enter.

---

# 32. Diagnostics are part of the compiler design

Every AST node should carry a **source span** from day one:

```text
file
start offset
end offset
line/column derivable
```

Do not bolt locations on later.

Diagnostics should structurally contain:

```text
error code
message
primary span
secondary spans
notes
```

Later the same diagnostic object can render as:

```text
human terminal output
JSON
LSP diagnostic
AI/tooling output
```

This supports our eventual AI-verification ambitions without complicating v0 syntax.

---

# 33. Toolchain direction

Ultimately one canonical CLI:

```text
eido build
eido run
eido test
eido check
eido fmt
eido doc
```

Later:

```text
eido architecture
eido verify
```

We should avoid early fragmentation into independent:

```text
build tools
formatters
package managers
test frameworks
```

The official language distribution should eventually own the normal workflow.

For the first compiler iteration, only:

```text
eido check
eido build
eido run
```

really matter.

---

# 34. Things explicitly **not in v0**

These ideas remain interesting but should **not block the compiler**:

| Feature | Status |
|---|---|
| Class inheritance | Rejected |
| Private interfaces | Rejected |
| Runtime interface dispatch | Deferred / not v0 |
| Reflection-heavy DI | Not intended |
| JVM/VM | Not intended |
| Direct LLVM backend | Deferred |
| Self-hosted compiler | Optional future experiment |
| Full formal proof system | Deferred |
| SMT verification | Deferred |
| Dependent types | Not planned for v0 |
| Prolog/unification/backtracking | Not v0 |
| Declarative business-rule language | Research later |
| Automatic multicore execution | Research later |
| Dataflow runtime | Research later |
| GPU compilation | Research later |
| Automatic SoA transformation | Research later |
| Tree-sitter compiler frontend | No; perhaps editor tooling later |
| Dynamic plugin loading | Deferred |
| Annotation/reflection framework system | Not part of current philosophy |

This is important because these discussions should not silently turn into v0 requirements.

---

# 35. Important unresolved semantic decisions

There are still a few things we **must deliberately leave open** instead of pretending they're solved.

### Memory model

Not locked.

We have not decided between:

```text
GC
reference counting
ARC/ORC
ownership
regions
escape-analysis-driven allocation
hybrid model
```

This is one of the most consequential future decisions.

Therefore AST/HIR should not encode assumptions such as:

```text
every class = heap pointer
```

A class type must remain abstract enough to permit value/stack/heap lowering later.

### Error model

Not locked.

We haven't decided:

```text
exceptions
Result
checked errors
sum types
panic
```

Do not implement a permanent exception mechanism yet.

### Nullability

Not locked.

Don't silently introduce Java-style `null`.

### Async/concurrency

Not locked.

### Dynamic dispatch

Not in v0, but not permanently constitutionally forbidden.

### Proof syntax

Not locked.

Only contracts are locked.

### `module.lang` grammar

Semantics are established; exact textual syntax still needs a small dedicated design pass.

### Multiple-interface extension

We've established that an interface can `extends` another interface. We have **not explicitly settled whether v0 allows**

```text
interface X extends A, B
```

or exactly one parent.

Do not silently choose until we settle it.

### `do`

We discussed Eiffel's `do` and liked its structure, but I do **not** regard it as a clearly locked keyword from our discussion.

I would therefore **not implement `do` yet** unless you confirm that it belongs in the source grammar.

That is precisely the kind of accidental assumption this baseline is intended to catch.

---

# 36. Ultimate architectural goal

The mature compiler/toolchain should eventually understand something like:

```text
module graph
    +
public interfaces
    +
interface implementations
    +
contracts
    +
provider composition
    +
actual dependency usage
```

and be able to answer:

```text
Which module depends on which?

Which contracts does this class implement?

Would replacing provider A with B compile?

Did this module expose a new API?

Did this change break an interface?

Is there an architectural cycle?

Which functions mutate which state?

Which contracts can be proven?

Which operations are potentially parallelizable?
```

Most of that belongs in **compiler/tooling intelligence**, not additional surface-language syntax.

---

# 37. Canonical philosophy

I would put these principles at the top of the compiler repository because they should guide every future feature proposal:

> **Keep implementation concrete. Make architectural boundaries explicit. Specify behavior where boundaries matter. Resolve and verify as much as possible before runtime.**

And:

> **The compiler may be sophisticated; ordinary application code should not have to be.**

And for your original motivation:

> **Java-like enterprise readability without requiring the JVM as the execution model.**

Those three statements are much more important than any individual keyword.

---

## Proposed v0 identity

For implementation purposes, I would currently label the project:

```text
Eido v0
```

with:

```text
implementation:
    Nim

primary backend:
    C → native

secondary backend:
    JavaScript, later

parser:
    handwritten recursive descent + Pratt

compiler AST:
    custom Nim structures

architecture:
    AST → HIR → MIR → backend

main language style:
    static + imperative + module/contract oriented

class inheritance:
    no

interface extension:
    yes, using `extends`

interface conformance:
    explicit `implements`

interfaces:
    module-boundary only

dynamic dispatch:
    not v0

contracts:
    require / ensure / invariant / old

formal verification:
    later

module organization:
    explicit module.lang file membership,
    directory hierarchy irrelevant
```

That is the baseline I would personally code against.

The **three items I would want you to explicitly approve/correct before I write the first compiler code** are: whether `do` exists in v0, whether an interface may `extends` multiple interfaces or only one, and whether `Eido` is acceptable purely as the temporary compiler/project codename. Everything else above reflects the design we've established rather than introducing a new architectural direction.
---

# 36. Current implemented v0 semantic addendum — receiver and class identity

> This section records later approved and implemented v0 semantics. Earlier
> sections remain preserved for design history, but this section takes
> precedence where they disagree.

## Current source punctuation

The implemented compiler uses semicolon-terminated statements and declarations:

```eido
var account = Account {
    balance: 100;
};

account.withdraw(10);
```

Braces terminate blocks. Older comma-terminated examples above are historical
and are not the current parser grammar.

## Explicit current-instance receiver and mutation

Inside an instance method, `self` explicitly denotes the current logical
instance:

```eido
class Account {
    Int balance;

    function withdraw(Int amount) {
        set self.balance = self.balance - amount;
    }

    function value() returns Int {
        return self.balance;
    }
}
```

Own fields require `self.field`; own-method calls require `self.method(...)`.
Unqualified calls remain top-level function calls. `self` is unavailable
outside instance methods.

Direct field mutation remains class-owned:

```eido
set self.balance = 10;     // valid inside Account
set balance = 10;          // invalid
set account.balance = 10;  // invalid
```

Parameters cannot be rebound with `set`. Existing field/parameter/local
non-shadowing rules remain in force even though `self` makes receiver access
explicit.

## Class-valued callable signatures

Function and method parameters/results may use declared nominal class types:

```eido
function charge(Account account, Int amount) {
    account.withdraw(amount);
}

function snapshot(Account account) returns Account {
    var result = copy account;
    return result;
}
```

A class parameter preserves the caller's logical object identity for the call.
Passing does not make a detached copy. The callee still cannot directly assign
the object's fields; it can invoke the object's behavior, whose implementation
may mutate its own `self`.

No `ref` or `copy` modifier is written on parameters or arguments.

## Explicit persistent identity decisions

When an existing class object establishes another persistent local binding,
Eido requires the relationship to be explicit:

```eido
var original = Account { balance: 100; };

var alias = ref original;
var detached = copy original;
var ambiguous = original; // invalid
```

`ref` preserves the same logical object identity.
`copy` creates a new detached logical object graph.

`copy` recursively detaches reachable class-valued fields. If the source
graph contains internal sharing or cycles, the copied graph preserves that
topology while sharing no copied mutable object with the source graph.

These are logical identity semantics, not pointer or allocation semantics.

## Class construction relationships

When an existing class value is placed into a class-valued construction field,
the persistent relationship must also be explicit:

```eido
var order = Order {
    account: ref account;
    snapshot: copy account;
};
```

A bare existing class value in that position is invalid. Fresh nested
construction and detached class-valued callable results may be used directly
because no additional identity choice remains to be made.

## Class-valued return boundary

A class-valued function or method return must produce fresh/detached identity.

Valid:

```eido
function create() returns Account {
    return Account { balance: 100; };
}

function snapshot(Account account) returns Account {
    var result = copy account;
    return result;
}
```

Returning existing identity is invalid:

```eido
return account;       // class parameter: invalid
return self;          // current receiver: invalid
return self.account;  // existing class field: invalid
```

`copy` and `ref` are not return modifiers and therefore cannot be written
directly in a return statement. They are also not callable-result modifiers.
A class-valued function/method result has already crossed a checked detached
return boundary, so it may initialize another local directly:

```eido
var snapshot = account.snapshot();
```

The following are invalid:

```eido
var snapshot = copy account.snapshot();
var alias = ref account.snapshot();
```

## Ordered mutation and detachment

Mutation before and after a copy intentionally have different semantics, and
the source makes the ordering visible:

```eido
function modify(Account account) returns Account {
    account.withdraw(100);
    var result = copy account;
    return result;
}
```

Here the caller's Account is mutated first because the parameter preserves
identity; the returned Account is then detached from the updated state.

By contrast:

```eido
function modified(Account account) returns Account {
    var result = copy account;
    result.withdraw(100);
    return result;
}
```

detaches first, so the original Account is not mutated by the later call.

## Class-valued `set`

Class-valued mutation follows the same persistent-relationship rule as local
binding and construction. Fresh construction and detached callable results flow
directly:

```eido
set account = Account { balance: 0; };
set account = createAccount();
```

When the source is an existing class object, the relationship must be explicit:

```eido
set account = ref otherAccount;   // preserve existing identity
set account = copy otherAccount;  // detached replacement
```

Bare `set account = otherAccount;` is invalid. The same rule applies to an own
class-valued field inside its class:

```eido
set self.account = Account { balance: 0; };
set self.account = createAccount();
set self.account = ref otherAccount;
set self.account = copy otherAccount;
```

External postfix field mutation remains invalid.

## Built-in String values

The implemented compiler now includes `String` as a built-in immutable text
value. String is neither one of the fixed-size scalar primitives nor a nominal
class, and it has no observable object identity.

```eido
var name = "Alice";
set name = "Bob";
```

String values may cross function/method parameter and return boundaries and may
be stored in class fields. `+` concatenates Strings; `==` and `!=` compare
text content. Ordered String comparison is unsupported.

The existing redundant-local-binding rule remains unchanged:

```eido
var first = "Eido";
var second = first; // invalid
```

`copy` and `ref` remain class-identity operations and are invalid for String.
The initial Nim backend lowers String to Nim `string`, but that storage model is
an implementation detail; Eido does not expose String buffer identity or commit
to Nim's allocation/reclamation strategy.

## Memory-model boundary remains open

The language now specifies logical identity flow—same identity versus detached
identity—and immutable String value semantics, but it still does **not** specify
allocation, lifetime, or reclamation.

The earlier unresolved memory-model choices remain unresolved:

```text
GC
reference counting
ARC/ORC
ownership
regions
escape-analysis-driven allocation
hybrid model
```

The current Nim backend's generated `ref object` layouts, hidden receiver
parameters, and memoized graph-copy procedures are implementation details.
The semantic AST/HIR must continue to avoid treating "class" as synonymous with
a particular heap/pointer/reclamation strategy.


---

# 39. Approved v0 repository, distribution, and installation layout

> Status: approved and structurally implemented for v0. This section defines
> how the Eido implementation repository and installed SDK are organized. It
> does not add source-language syntax.

## One v0 monorepo, explicit component boundaries

Eido v0 is developed in one repository. Compiler implementation, standard
library, official packages, tool adapters, installer logic, tests, examples,
and documentation remain colocated for iteration speed, but they must live in
separate top-level areas according to ownership:

```text
eido/
├── compiler/
│   ├── src/
│   │   ├── frontend/
│   │   ├── semantic/
│   │   ├── types/
│   │   ├── hir/
│   │   ├── backend/
│   │   └── tooling/
│   └── tests/
│
├── stdlib/
│   ├── src/
│   └── tests/
│
├── packages/
│   └── ...
│
├── tools/
│   ├── cli/
│   ├── mcp/
│   └── lsp/          # later
│
├── installer/
│
├── tests/
│   └── integration/
│
├── examples/
├── docs/
├── eido.nimble
└── README.md
```

The exact files inside an area may evolve, but the ownership boundaries are
part of v0 architecture.

## Compiler

`compiler/` owns implementation of the Eido language and compiler pipeline:

```text
source
  -> lexer/parser/AST
  -> semantic analysis
  -> typed/resolved HIR
  -> backend
  -> compiled artifact
```

The compiler must not absorb standard-library APIs, package implementations, or
MCP protocol logic merely because those components use compiler information.

## Standard library

`stdlib/` contains foundational APIs guaranteed to ship with an Eido
installation. The standard library is ordinary Eido-facing functionality, not
additional language syntax.

Expected categories may eventually include foundational collections, text/byte
utilities, console/basic I/O, filesystem, process/environment, time, and basic
network primitives. Their exact APIs are specified independently of the core
language syntax.

Every conforming Eido SDK installation ships the standard library. Users do not
install it as a normal third-party dependency.

## Packages

`packages/` contains higher-level libraries developed in the same monorepo
for v0 convenience. Packages are built on top of the Eido language and the
standard library; they are not compiler extensions.

Examples of package-level concerns include JSON, HTTP, database drivers,
serialization, web frameworks, logging frameworks, or other higher-level
application facilities.

A package may depend only on the subset of stdlib and other packages it needs.
A package can later move to an independent repository without changing the Eido
language definition.

Dependency direction is conceptually:

```text
language/compiler
      ↓
standard library
      ↓
packages
      ↓
applications
```

This is a layering model, not a requirement that every package use every stdlib
module.

## Runtime directory is not created speculatively

Eido v0 does not create a top-level `runtime/` component merely because many
compiled languages have one. The current compiler delegates execution support
such as String storage and class allocation/reclamation to the current backend
implementation.

A dedicated `runtime/` area is introduced only if Eido later owns hidden
support code required by language semantics themselves, for example a custom
memory manager, String representation, panic machinery, or other support linked
into compiled programs.

Native compilation and a runtime are not mutually exclusive; if such runtime
support is later required it may be statically linked into the native binary.

## Tools

`tools/` contains user/tool integrations over stable compiler capabilities.
The intended front doors are:

```text
tools/cli/   human command-line adapter
tools/mcp/   MCP adapter for LLM/agent clients
tools/lsp/   editor/LSP adapter when implemented
```

Protocol-specific logic belongs here rather than in the compiler's semantic
implementation.

## Single user-facing command

The intended installed UX uses one `eido` executable/command surface rather
than unrelated binaries for each tool:

```text
eido build
eido run
eido check
eido test
eido fmt
eido package ...
eido mcp
eido lsp        # later
```

Internally these operations may be separate components.

## Installed SDK root

Eido uses one logical installation root, referred to architecturally as
`EIDO_HOME`. A user-local layout is conceptually:

```text
EIDO_HOME/
├── bin/
│   └── eido
├── versions/
│   └── <version>/
│       ├── compiler/
│       ├── stdlib/
│       └── support/
├── packages/
├── cache/
└── config/
```

Only the executable location needs to be exposed through the operating-system
`PATH`. The exact platform-specific physical root may differ; the logical
layout and resolver behavior remain stable.

A versioned SDK layout is preferred even during v0 so upgrades and future
rollback/version-selection do not require redesigning the installation format.

## Package storage and project isolation

Packages may be physically cached centrally under EIDO_HOME, but a project
must see only dependencies selected for that project. Installing a package into
the machine-wide/user-wide cache must not silently inject arbitrary versions
into every project.

The intended model is:

```text
central package store/cache
          +
project dependency declaration/lock
          ↓
deterministic dependency graph
```

The exact project manifest syntax is not yet locked.

## Logical imports, not physical filesystem paths

Eido source imports/modules must identify logical language/library/package
entities rather than hard-coded installation paths. Source code must not need
to know whether a library physically lives under EIDO_HOME, the project tree,
or a package cache.

The resolver will eventually distinguish at least:

```text
project source
project-declared dependencies
installed/cached package content
bundled standard library
```

The exact source-level import/module syntax and final precedence rules are
specified when multi-file/module resolution is implemented; this section locks
the separation between logical identity and physical storage.

## Installer responsibility

The installer turns build outputs into a coherent Eido SDK. At minimum it must
make the selected compiler/tooling version and matching standard library
available together, configure the user-facing `eido` command, and establish
the SDK/package/cache directories needed by resolution.

Official packages may be distributed or cached by the same ecosystem tooling,
but packages remain semantically separate from stdlib and are not implicitly
part of the language.

---

# 40. Approved v0 LLM/MCP-native compiler tooling architecture

> Status: approved architecture with the protocol-neutral compiler tooling seam
> now established. MCP transport/tools are not yet implemented. Eido is intended
> to expose compiler semantic knowledge to LLMs, agents, editors, CI, and other
> tooling without making MCP part of compiler semantics.

## Core principle

The compiler is a semantic authority, not merely a source-to-binary command.
Any semantic fact the compiler knows should be obtainable in structured form
without forcing tooling to scrape human-readable diagnostics or reconstruct the
fact by reparsing source independently.

Examples include:

```text
resolved symbols and types
call relationships
class identity/provenance flow
field reads and mutations
module/dependency relationships
contract obligations and results
compiler diagnostics
source spans
compilation/verification status
```

## Compiler tooling API before protocol adapters

MCP-specific behavior must not be embedded throughout lexer/parser/semantic
code. The architecture is:

```text
                    compiler core
                         │
                         ▼
               compiler tooling API
              / semantic project service
                         │
          ┌──────────────┼──────────────┐
          ▼              ▼              ▼
         CLI            MCP            LSP
```

The compiler-side `compiler/src/tooling/` area exposes stable semantic
operations. `tools/mcp/`, `tools/cli/`, and future integrations translate
their respective protocols to that API.

The compiler core must not depend on MCP, a specific LLM vendor, an editor, or
JSON-RPC.

## Semantic operations, not compiler internals

The public tooling surface exposes user/tooling concepts rather than internal
procedures such as parser helper functions.

Good tooling capabilities include concepts such as:

```text
open/load project
check project/module/symbol
compile project/module
inspect symbol
find symbols
find references
inspect type
inspect expression type
callers/callees
dependency graph
semantic context around a symbol
verification/contracts
explain diagnostic
change impact / affected dependency cone
```

Internal operations such as `parseAddExpression` or a backend-specific HIR
helper are not stable public agent tools.

## Structured diagnostics

Diagnostics must evolve toward stable machine-readable records while remaining
renderable for humans. A diagnostic should be able to expose information such
as:

```text
stable diagnostic code
severity
source span
human message
related symbols/types
expected/actual semantic facts
machine-actionable suggestions where safe and deterministic
```

Human CLI output is a presentation of this structured diagnostic model. MCP,
LSP, CI, and other tools consume the structured representation directly.

## Stable semantic identities

Long-lived tooling should be able to refer to resolved program entities without
relying only on ambiguous display names. Compiler tooling may therefore expose
stable session/project identifiers for symbols, types, modules, diagnostics, or
other semantic entities as the project model matures.

Display names remain available for humans, but agent/tool operations should not
need to guess between same-named declarations.

## Project/session model and selective analysis

The tooling architecture should support a loaded project/session rather than
requiring every operation to recompile all source from zero.

Conceptually the compiler may retain reusable state such as:

```text
parsed source
symbol tables
typed/resolved HIR
dependency graph
verification state
backend artifacts/cache metadata
```

When a file changes, the compiler should eventually invalidate and recompute the
smallest sound affected dependency cone.

The external tooling surface may request scopes such as:

```text
symbol
file/module
changed set
dependency cone
whole project
```

Selective checking/verification/compilation is an optimization and tooling
capability; it must preserve the same semantics as whole-program analysis.

## LLM-oriented semantic context

Eido tooling should be able to produce a bounded, compiler-grounded context for
a symbol/module/project rather than requiring an LLM to ingest the entire
source tree.

A context result may include, subject to a requested depth/budget:

```text
signature/type
contracts
fields read
fields mutated
class identity relationships
callers/callees
relevant types
module/package dependencies
invariants/obligations
source locations
```

Context selection must derive from the compiler's resolved graph so an LLM can
zoom into relevant semantic neighborhoods instead of performing repository-wide
text search for every task.

## Eido-specific identity and mutation facts are first-class tooling data

Eido's class semantics contain information that ordinary source inspection can
misinterpret. Tooling should expose these facts explicitly.

For example, after:

```eido
set current = ref account;
```

tooling can report that `current` has existing/shared logical identity
provenance. After:

```eido
set current = copy account;
```

tooling can report detached provenance.

The same principle applies to construction relationships, return-boundary
provenance, mutations, and later contract/invariant effects.

## Verification tooling

When contracts are implemented, tooling should permit focused verification and
explanation at the relevant semantic scope. Results should distinguish facts
such as:

```text
type/semantic check success
precondition/postcondition status
invariants affected
obligations discharged
obligations not discharged
runtime-check-only obligations
counterexample/path information when available
```

Formal proof is not required for the tooling architecture. v0 may begin with
contract type-checking/runtime-check lowering and progressively expose stronger
verification results later.

## MCP adapter

MCP is the first-class LLM/agent transport planned for v0 tooling. The intended
local entry point is conceptually:

```text
eido mcp
```

The MCP server should normally use local stdio transport so an MCP-capable
client can launch the installed Eido toolchain without a separately managed
network service.

The MCP surface should remain compact and semantic. A small initial surface may
cover:

```text
project open/summary
check
compile
inspect symbol
find symbols
find references
dependency graph
semantic context
```

Later additions may include verification, contract inspection, diagnostic
explanation, architecture analysis, and change-impact queries.

Exact MCP tool names and schemas are intentionally not frozen here; the stable
contract is that MCP adapts the compiler tooling API rather than becoming the
semantic implementation itself.

## Language/tooling knowledge ships with Eido

An installed Eido SDK should make the authoritative v0 language/tooling guide
available to agents instead of assuming their pretrained knowledge is current.
This may be exposed through MCP resources/tools, generated agent skill files,
CLI output, or equivalent mechanisms.

The source of truth remains the versioned Eido specification/compiler metadata,
so the guide shipped with a particular compiler version describes that compiler
version.

## Other consumers share the same semantic service

MCP is not exclusive. The same tooling API is intended to support:

```text
CLI human workflows
MCP/LLM agents
LSP/editors
CI/build automation
future IDEs or custom agent protocols
```

This prevents semantic divergence between what the compiler, editor, CI, and AI
assistant believe about a program.

## LLM-native does not mean LLM-dependent

Eido programs and compilation must remain deterministic and usable without an
LLM. AI-native tooling means the compiler exposes structured, selective,
semantically grounded operations that make agents more reliable; it does not
make model inference part of ordinary compilation semantics.


---

# 41. Current implemented v0 project and multi-source compilation model

> Status: approved and implemented foundation. This section is authoritative
> for project/source compilation behavior until the module/package grammar is
> implemented.

## Source identity

Compilation operates on explicit `SourceUnit` values. Each source unit carries:

```text
project-local SourceId
path
text
```

Lexer tokens and all derived `SourceSpan` values retain source id/path plus
source offsets, line, and column. Composite AST spans preserve the originating
source identity. File-aware lexer/parser/semantic diagnostics therefore report
locations such as `src/account.eido:3:9`.

## Project target

The compiler-level root is `EidoProject`:

```text
EidoProject
├── target
│   ├── executable
│   └── library
└── sources: SourceUnit[]
```

An executable project requires one top-level `function main()` entrypoint.
`main` must have zero parameters. Multiple functions named `main` are rejected
by the ordinary duplicate top-level function rule.

A library project does not require `main`. Its HIR/backend output carries no
executable main harness. This distinction is required for future stdlib,
packages, reusable modules, and project targets.

## Multi-source compilation

Every source unit is lexed and parsed independently. The resulting top-level
class/function declarations are then merged into one project AST declaration
universe before semantic declaration collection and body analysis.

Therefore, during this pre-module stage:

```text
file order does not define visibility
classes may reference classes declared in another supplied file
functions may call functions declared in another supplied file
functions/methods may use class types declared in another supplied file
duplicate top-level class/function names are project-wide errors
```

There is currently no source-level `import` grammar, module visibility rule,
package boundary, or namespace derived from physical directories. Supplying a
source unit to the project currently places its declarations in the same global
project declaration universe.

## Tooling and CLI boundary

The protocol-neutral compiler tooling API now exposes project checking and
project compilation. The old single-source compiler entry remains only as a
compatibility/convenience wrapper that creates a one-source executable project.

The CLI accepts multiple explicit source files:

```text
eido build main.eido account.eido service.eido -o app
```

It creates identified SourceUnits and one executable EidoProject, then delegates
to the same compiler tooling/project pipeline intended for future LSP and MCP
adapters. No project manifest or automatic directory crawl is defined yet.

## Entrypoint output note

The current Nim backend still prints the result of a value-returning `main`.
That behavior is retained temporarily because existing language acceptance tests
need an observable result before console/process stdlib semantics exist.

It is not the final application contract. The durable entrypoint decision is:

```text
executable target -> top-level zero-parameter main required
library target    -> no entrypoint required
```

Final process exit-code rules and explicit console output behavior will be
specified with process/stdlib support rather than inferred from the temporary
backend harness.

## Parallel toolchain completion policy

From this point, Eido v0 is developed as a language + development experience,
not as syntax/semantics first and tooling later. When v0 language semantics are
finished, the intended normal authoring experience should already include the
core facilities expected from a Java-like development environment:

```text
project-aware build/check/run
automatic syntax and semantic highlighting
live diagnostics
hover/type/signature information
member completion after '.' and ordinary symbol completion
signature help
go-to-definition and find references
safe rename when supported by compiler symbol identity
canonical formatting
MCP project/check/inspect/context access
```

LSP/editor and MCP implementations are adapters over the compiler tooling API.
They must not implement independent parsing, name resolution, typing, or member
lookup. Tooling capabilities are added incrementally alongside the compiler
facts required to support them.


---

# 42. Current implemented v0 structured diagnostics and semantic check model

> Status: approved and implemented foundation. This section defines the
> machine-readable diagnostic contract and the first semantic-only CLI/tooling
> check operation used by future LSP/MCP integrations.

## Structured diagnostics

Compiler-reported user errors are represented as `CompilerDiagnostic` data,
not only human-readable exception strings. A diagnostic contains:

```text
code
severity
message
optional SourceSpan
```

Severity supports error, warning, information, and hint categories. Current
compiler checking emits errors; the broader vocabulary is reserved for later
analysis/tooling without changing the transport model.

Stable diagnostic codes are part of the tooling contract. The initial v0 codes
are:

```text
EIDO1000  generic source-bound compiler error
EIDO2001  project contains no source units
EIDO2002  executable project has no main function
```

EIDO1000 intentionally acts as a migration code for existing parser/semantic
errors. More specific codes are introduced incrementally when language areas are
touched; v0 does not require a one-time rewrite of every existing failure site.
Human diagnostic messages may improve while the stable code remains the primary
machine identity.

## CompilerError bridge

Existing compiler phases continue to use exception-based control flow for
fail-fast user errors. `CompilerError` is ValueError-compatible so existing
compiler tests/callers remain valid, but it embeds the authoritative structured
`CompilerDiagnostic`.

Protocol/tool adapters must consume the embedded diagnostic or tooling result;
they must not parse the human exception message to reconstruct source spans,
severity, or diagnostic identity.

Unexpected internal compiler/backend invariant failures are not converted into
normal user diagnostics. They remain exceptional so implementation defects are
not hidden as ordinary source errors.

## ProjectCheckResult

The protocol-neutral tooling API exposes semantic project checking as:

```text
ProjectCheckResult
├── success
├── diagnostics[]
└── program        # analyzed HIR when successful
```

`checkProject(project)` performs project parsing and semantic analysis only. It
does not invoke the Nim emitter, write generated Nim, or run the native backend
toolchain.

The current compiler is fail-fast, so one check currently yields zero or one
user diagnostic. The public result is sequence-shaped deliberately so parser
recovery and multi-diagnostic aggregation can be added later without changing
CLI/LSP/MCP result contracts.

Compiler-internal code that needs failure to remain exceptional may use the
strict checked-project path instead of the diagnostic-returning tooling path.

## CLI semantic check

The user-facing command is:

```text
eido check <source.eido> [<source.eido> ...]
```

All supplied files form the same executable project source set under the
current pre-module model. A successful check exits with status 0. Compiler
diagnostics are rendered to stderr and cause status 1. Example rendering:

```text
src/main.eido:3:9 error EIDO1000: unknown function 'broken'
```

`eido check` accepts no output path because it produces no backend artifact.
Library-target CLI selection remains a later project/manifest concern; the
compiler tooling API already supports checking library projects directly.

## LSP/MCP significance

This structured check path is the shared basis for future live editor and agent
diagnostics:

```text
EidoProject
    ↓
checkProject
    ↓
ProjectCheckResult
    ├── CLI -> human rendering
    ├── LSP -> protocol diagnostics
    ├── MCP -> machine-readable agent diagnostics
    └── CI  -> automated check results
```

No adapter owns independent Eido diagnostic semantics. File identity, source
spans, codes, severity, and messages originate in the compiler/tooling layer.
