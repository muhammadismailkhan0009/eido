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

`copy` and `ref` are not `set` operands. A class-valued local may currently
be rebound from a fresh construction or a detached class-valued callable result:

```eido
set account = Account { balance: 0; };
set account = createAccount();
```

Rebinding from an existing class object remains invalid:

```eido
set account = otherAccount;       // invalid
set account = copy otherAccount;  // invalid in set
set account = ref otherAccount;   // invalid in set
```

Class-valued field mutation through `set self.field = ...` remains outside the
current implemented slice.

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
