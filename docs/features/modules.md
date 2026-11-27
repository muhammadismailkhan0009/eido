# Modules

Eido modules are mandatory architecture manifests for normal projects. They are
not source namespaces and do not add keywords to `.eido`.

A normal project is entered through `module.yaml`:

```yaml
module: payments

sources:
  - Payments.eido
  - PaymentCoordinator.eido

children:
  processor:
    path: processor

dependencies:
  - logging

exports:
  - Payments

allowsExternalImplementation: []

provides:
  PaymentProcessor:
    by: processor

adopts:
  - processor.ProcessorHealth

policySources: []
```

The v0 parser accepts the YAML subset needed by this schema: mappings,
sequences, plain/quoted scalars, inline scalar lists such as `[storage, io]`,
empty `[]`/`{}`, and small inline mappings
such as `processor: { path: processor }`. YAML anchors/tags and unrelated YAML
features are intentionally outside the manifest grammar. Only `module` is
mandatory; omitted collection properties are empty.

Every `.eido` source uses one of three mutually exclusive categories: a single non-function top-level declaration (class, interface, layout, or layout selection), one or more standalone functions other than `main` (including native functions), or a lone top-level `function main`. Comments and documentation do not count as declarations. Class and interface methods remain unrestricted by this file rule. No filename convention is enforced; the rule applies equally to standalone and manifest projects, including compile-time policy sources. Cross-file name resolution retains canonical module identities and enforces the internal directory boundary below.

## Architectural meaning

- `module` is the local module name.
- `sources` lists files or recursively discovered directories owned directly by
  the module. Files outside registered entries are ignored.
- `children` is the only mechanism that establishes parent/child module
  containment. Filesystem nesting alone creates nothing.
- `path` is only the physical location of a child's `module.yaml`, relative
  to the parent. Architectural identity comes from parent + child name.
- `dependencies` are explicit direct module dependencies.
- `exports` are the module's outward API.
- `allowsExternalImplementation` is an optional sequence of locally owned, explicitly exported
  interface names whose implementations may live outside the owning module family.
  It does not grant visibility or extension permission.
- `adopts` accepts exported child APIs into the parent family under the original
  module rules, and authorizes named declarations for internal cross-directory
  use. Local directory adoption does not expose a declaration outside its module.
- `provides` records that a child module fulfills a parent-owned interface
  contract. The compiler validates that the contract is owned by the parent and
  that the declared provider subtree contains an explicit implementation.
- `policySources` optionally declares build-machine Eido source that makes this
  module selectable as a memory policy. These files use the compiler-facing
  memory-policy API and never enter the target binary; the module's ordinary
  `sources` become its hidden target runtime only when the module is selected.

Canonical child identity is derived:

```text
payments
  child processor
    child stripe

=> payments.processor.stripe
```

A child manifest declares only its local name. It does not declare its parent.

## Directory registration and internal architecture

A single manifest can control all ordinary directories:

```yaml
module: network
sources: [.]
dependencies: [storage]
adopts:
  - address.SocketAddress
  - status.NetworkStatus
  - tcp.TcpConnection
exports: [Tcp, TcpConnection]
allowsExternalImplementation: [TcpConnection]
```

An individual file entry is still supported. Directory entries recursively
select `.eido` files in lexical path order, preserving manifest entry order.
Discovery does not cross a declared child root or any nested `module.yaml`;
only declared children are loaded as modules. Logical module containment is
independent of physical paths: a test module may declare its enclosing package
with `path: ..`. Its own manifest subtree remains eligible for discovery,
while the enclosing package cannot claim sources across that manifest boundary.
Symbolic links are not followed.
Files in `policySources` are excluded from directory discovery; explicit
duplicate registrations (including overlapping directories) are errors.
Directory entries must be inside the owning module. Existing explicit
external support-file registrations remain possible outside independently
manifest-owned trees.

An ordinary directory is **not** a module. For internal access, files directly
beside the manifest form one group, and each immediate directory subtree forms
another group. Deeper directories inside that subtree introduce no additional
access boundary unless they are separately declared modules. For example,
`tcp/options` and `tcp/results` may freely reference one another; `tcp` cannot
reference `address.SocketAddress` unless the parent lists it in `adopts`.

Adopt a local declaration by its immediate directory and name, e.g.
`address.SocketAddress`. For declarations directly beside the manifest use a
bare name, e.g. `RootHelper`. Explicit external support files use their first
relative directory group, e.g. `../support.Text`. The name identifies the
declaration, not a source file or a new canonical namespace. Internal adoption
may name an ordinary class, interface, top-level function or named layout.
It authorizes all consumers within the owning module, without listing them.
Unknown, incorrectly located and duplicate adoption entries are rejected.

Actual child-module references retain their existing adoption semantics and
take precedence over an identically named ordinary directory. Local adoption
does not authorize other modules, does not imply public export, and does not
relax the existing explicit export-root restrictions. Public exports alone
do not grant internal cross-directory access. An internal adopted interface
participates in the architectural surface without becoming externally visible.

The compiler checks explicit imports, qualified and implicit type references,
constructors, signatures, inheritance/implementation references, class-owned
access, top-level calls, contracts, and resolved inferred types/member uses.
Each local declaration used across a boundary needs its own adoption;
adopting one directory declaration does not silently adopt its complete type
closure. Generic declaration permissions cover its specializations; template
parameter substitutions alone do not create new coupling for the template
author. Source imports keep the canonical module name, e.g.
`import eido.stdlib.network.SocketAddress;`, not a directory-based path.

## Memory-policy modules

A module may provide a replaceable target-memory policy without compiler changes:

```yaml
module: custom_memory

sources:
  - runtime.eido

policySources:
  - policy.eido

children: []
dependencies: []
exports: []
provides: {}
adopts: []
```

`policy.eido` executes only during compilation and binds generic program lifecycle
events through `MemoryPolicy`. `runtime.eido` is analyzed/emitted only when this
module is selected through the compilation memory-policy option. The SDK policies `eido.stdlib.memory.managed` and `eido.stdlib.memory.rc` use exactly this schema; custom policies are not a separate compiler extension mechanism.

Policy source is intentionally separate from target source so build-machine
inspection code and compiler API declarations cannot leak into the executable.

## Propagation

Architecture is asymmetric:

```text
parent -> child    allowed where parent authorizes
child  -> parent   never automatic
```

Parent dependencies propagate downward. Parent exports and explicitly adopted
child exports are visible within the family. Internal directory adoptions
remain local to the declaring module. A child export does not rise to its
parent or siblings unless the parent adopts or re-exports it.

Containment controls visibility; dependencies control use.

## Current public surface

Modules do not distinguish DTO/data classes from behavioral classes once a type is reachable through the public API closure.

Explicit export roots are intentionally narrower: an export must be an interface or a static-only class. A static-only class has no fields and all of its Eido-bodied methods are inferred static (native class methods are static by definition). Concrete instance classes cannot be named directly in `exports`.

From each legal export root, the compiler computes the complete transitive nominal API closure through:

- class fields;
- class method parameter/result types;
- interfaces implemented by a class;
- parent interfaces;
- interface method parameter/result types;
- nested generic type arguments.

Every transitively reachable class/interface becomes available to consumers as the same ordinary Eido declaration it already is. A reachable class may therefore be constructed, have fields read, and have its methods called according to the normal class rules. The compiler does not project a data-only view and does not warn that a behavioral class became reachable; the restriction applies to explicit architectural roots, not to required signature closure.

Declarations that are not reachable from an allowed API surface remain
module-internal. Top-level functions remain module-internal and cannot be
exported.

Interfaces are closed to their owning module family by default.
Parent-owned `provides` contracts and their full nominal closure propagate only
into the declared provider subtree. External consumers may implement a public
interface only when its owning module explicitly authorizes implementation:

```yaml
exports:
  - TcpConnection
  - TcpListener
allowsExternalImplementation:
  - TcpConnection
```

The optional list defaults to empty. Each entry names a distinct, locally owned
interface named directly in the owning module's `exports`. Transitive
visibility alone is not sufficient. Unknown names, classes, non-exported
contracts and foreign/re-exported declarations are rejected. Permission does not expose an
interface or create a dependency: ordinary visibility checks still apply.
Every inherited interface must independently permit implementation by the
class's module, so opening a child contract cannot bypass a closed ancestor.
Interface `extends` remains limited to the owning module family, even for an
externally implementable interface. Generic permissions name the declaration
without type arguments and cover its valid specializations. `provides`, `adopts`,
export roots, factory selection and runtime dispatch retain their existing rules.

## Dependency graph

Explicit module dependencies must be acyclic and are non-transitive as usage
relationships. A child may consume dependencies supplied by its ancestors
without declaring a dependency back to the parent.

API closure is different from dependency transitivity. If module A's exported
surface references an exported class/interface from dependency B, that specific
reachable declaration becomes part of A's public API and is therefore visible
to consumers of A. Unrelated declarations from B remain invisible unless they
also become reachable through A's API graph.

## Source imports

A module project may begin each source file with explicit nominal imports:

```eido
import eido.stdlib.io.Console;
import eido.stdlib.storage.Storage;

class BufferPrinter {
    function printCapacity(Storage<Byte> buffer) returns Int {
        Console.writeLine("Buffer capacity");
        return Storage<Byte>.capacity(buffer);
    }
}
```

Each import uses the full canonical module path and one class or interface name,
terminated by a semicolon. Import the generic declaration without type arguments;
specialize it normally at use sites. Imports are file-local bindings and must
precede all declarations. They do not count as top-level declarations for source
file isolation. Comments are permitted before or between imports.

The manifest remains authoritative for module ownership, dependencies,
exports, provider contracts, adopted APIs and external implementation
permission. Imports select already visible declarations, including types
reachable through an existing authorized API closure, and cannot create a
dependency or make a private declaration public. Imported references in public
signatures participate in the existing closure only after the binding is
authorized; the signature cannot grant its own import permission.

Unknown or inaccessible targets, repeated imports and conflicting short names
(including conflicts with a module-local nominal) are errors. Different files
may bind the same short name differently. No wildcard imports, aliases, function
imports or filesystem-relative paths are supported. Existing unqualified
resolution and explicit qualified references remain supported; import
requirements for cross-module references are not introduced in this increment.
The compiler resolves imports before ordinary semantic analysis, with no runtime
effect. The editor indexes import references and supports go-to-definition,
including embedded SDK declarations.

## Name resolution and qualification

Declarations are internally identified by canonical module identity plus local name, for example `shop.payments.Result` and `shop.users.Result`. Same-named declarations in different modules are legal.

Unqualified lookup prefers the current module. Otherwise it resolves when exactly one declaration with that local name is visible through the effective module API surfaces. Multiple visible matches are an ambiguity error.

Use module qualification to disambiguate:

```eido
function read(payments.Result value) returns Int {
    return value.code;
}

var result = payments.Result { code = 42; };
var value = payments.Factory.create();
```

The qualifier is resolved through the module graph; it does not grant access to declarations that are otherwise invisible. Ordinary value member access remains unchanged.

Top-level functions stay module-internal. Same-named top-level functions in different modules are legal internally, but cross-module function calls are not introduced.


### Implicit SDK standard library

Normal module projects automatically receive the SDK module `eido.stdlib` as a root dependency, and ordinary child modules inherit visibility through the same dependency rules used for user modules. The stdlib itself is declared by the real `stdlib/module.yaml`; its source ownership and export roots therefore come from the same manifest schema used by ordinary Eido modules. Projects must not add repository-relative stdlib source paths to their manifests.

The bootstrap compiler expands the real stdlib manifest tree using the same directory discovery as user projects at compiler build time, and embeds the manifest plus the selected source payloads so an installation created with `nimble install` can compile projects outside the compiler repository. Bootstrap loading parses the embedded manifest with the normal module-manifest parser rather than maintaining a separate handwritten module definition. The reserved canonical identity `eido.stdlib` is SDK namespace policy; module/dependency visibility machinery remains authoritative.

## Project and build tooling

`module.yaml` remains the architecture root consumed by the compiler project model. The official `eido` project tool discovers the outermost ancestor manifest, so normal commands can run from the project root or one of its child-module directories:

```text
eido check
eido build
eido run -- <application arguments...>
eido clean
```

The default tool writes its artifacts under `<project>/build/`, with the native executable in `build/bin/` and generated Nim backend source in `build/generated/nim/`. These locations are tooling policy rather than language semantics.

Explicit manifests and custom output paths remain supported for CI and external orchestration:

```text
eido check module.yaml
eido build module.yaml -o app
eido run module.yaml -- <application arguments...>
```

Standalone source compilation remains available independently through `eido compile <source.eido>... -o <output>`. Future build systems may bypass the default CLI workflow and consume the same project/compiler APIs directly.
