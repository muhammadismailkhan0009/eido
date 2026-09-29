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

provides:
  PaymentProcessor:
    by: processor

adopts:
  - processor.ProcessorHealth
```

The v0 parser accepts the YAML subset needed by this schema: mappings,
sequences, plain/quoted scalars, empty `[]`/`{}`, and small inline mappings
such as `processor: { path: processor }`. YAML anchors/tags and unrelated YAML
features are intentionally outside the manifest grammar.

Each listed `.eido` source may contain at most one outermost nominal declaration total: one class or one interface. Top-level functions may coexist in that file. Multiple same-level classes/interfaces must be split into separate source files; nested nominal declarations are not part of the current grammar.

## Architectural meaning

- `module` is the local module name.
- `sources` is the complete explicit list of Eido files owned directly by the
  module. Undeclared `.eido` files are ignored.
- `children` is the only mechanism that establishes parent/child module
  containment. Filesystem nesting alone creates nothing.
- `path` is only the physical location of a child's `module.yaml`, relative
  to the parent. Architectural identity comes from parent + child name.
- `dependencies` are explicit direct module dependencies.
- `exports` are the module's outward API.
- `adopts` explicitly accepts an exported child contract/API into the parent
  family. Nothing propagates upward automatically.
- `provides` records that a child module fulfills a parent-owned interface
  contract. The compiler validates that the contract is owned by the parent and
  that the declared provider subtree contains an explicit implementation.

Canonical child identity is derived:

```text
payments
  child processor
    child stripe

=> payments.processor.stripe
```

A child manifest declares only its local name. It does not declare its parent.

## Propagation

Architecture is asymmetric:

```text
parent -> child    allowed where parent authorizes
child  -> parent   never automatic
```

Parent dependencies propagate downward. Parent exports and explicitly adopted
child exports are visible within the family. A child export does not rise to its
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

Interfaces are still closed to their owning module family by default.
Parent-owned `provides` contracts and their full nominal closure propagate only
into the declared provider subtree, while external dependencies may consume an
exported interface but may not implement it.

## Dependency graph

Explicit module dependencies must be acyclic and are non-transitive as usage
relationships. A child may consume dependencies supplied by its ancestors
without declaring a dependency back to the parent.

API closure is different from dependency transitivity. If module A's exported
surface references an exported class/interface from dependency B, that specific
reachable declaration becomes part of A's public API and is therefore visible
to consumers of A. Unrelated declarations from B remain invisible unless they
also become reachable through A's API graph.

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

Normal module projects automatically receive an exported compiler-owned module named `eido.stdlib` as a root dependency. Its current public classes are `Process` and `Console`, and ordinary child modules inherit visibility through the same dependency rules used for user modules. Projects must not add repository-relative stdlib source paths to their manifests.

The bootstrap compiler embeds these declarations so an Eido installation created with `nimble install` can compile projects outside the compiler repository. This is an SDK-provided dependency, not source-language magic; the module/dependency visibility machinery remains authoritative.

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
