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

The current module public surface is:

```text
interfaces          behavioral contracts
static-only classes facades/factories/entry points
API data types      pending
```

A static-only exported class has:

```text
zero fields
+
all methods inferred static
```

Concrete instance classes cannot cross module boundaries. Top-level functions
are always module-internal. Cross-module construction or use of a concrete
behavioral class as a field/parameter/result type is rejected.

Interfaces are closed to their owning module family by default. Parent-owned
`provides` contracts propagate only into the declared provider subtree, while
external dependencies may consume an exported interface but may not implement
it.

A public interface cannot currently mention a concrete class parameter/result.
Distinct API data types and transitive public API data closure remain the next
boundary feature.

## Dependency graph

Explicit module dependencies must be acyclic and are non-transitive. A child may
consume dependencies supplied by its ancestors without declaring a dependency
back to the parent.

The current module-aware resolver still requires interface, class, and
top-level-function names to be project-unique. Module-qualified internal symbol identities are a
separate resolver improvement; this limitation does not weaken visibility or
dependency enforcement.

## CLI

Normal project commands require the manifest:

```text
eido check module.yaml
eido build module.yaml -o app
```

Raw multi-source compiler helpers remain for bootstrap/compiler tests, but they
are not the normal user project model.
