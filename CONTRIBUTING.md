# Contributing to Eido

Eido is pre-alpha and still evolving quickly. Contributions are welcome, but language changes should preserve the project's emphasis on explicit semantics, low cognitive load, compiler-owned guarantees, and strong architectural boundaries.

## Development setup

Requirements:

- Nim 2.2+ and Nimble;
- a native C toolchain;
- Git.

From the repository root:

```bash
nimble build -y
nimble test -y
nimble buildLsp -y
```

Run the enterprise demo with the freshly built local compiler:

```bash
cd examples/enterprise_demo
../../eido check
../../eido run -- approve "Acme GmbH"
```

## Change workflow

For language behavior, prefer a behavior-driven change:

1. Define the intended semantic rule.
2. Add or update focused parser/semantic/backend/tooling tests as applicable.
3. Confirm the focused test fails for the intended reason.
4. Implement the smallest coherent semantic change.
5. Add a language-facing feature/integration test when runtime behavior changes.
6. Update relevant documentation in `docs/features/` and project decision/map files when architecture or locked semantics change.
7. Run the full test/build validation before committing.

Pure refactors do not need an artificial failing test, but must preserve the full suite.

## Compiler architecture

Keep semantics in the compiler rather than duplicating them in adapters:

```text
source -> AST -> semantic analysis -> HIR -> backend/tooling
```

The CLI, LSP, VS Code extension, and future MCP/build integrations should consume compiler/project APIs instead of independently parsing or inferring Eido behavior.

Prefer semantic locality: focused modules and thin coordinators are favored over large hub files.

Every production Nim `proc` in this repository must have an immediately preceding `##` documentation comment; architecture tests enforce this convention.

## Tests

`nimble test -y` runs compiler suites, feature execution tests, CLI integration, Eido-written CLI dogfooding, and LSP integration.

Before submitting a change, also run:

```bash
nimble build -y
nimble buildLsp -y
git diff --check
```

## Scope

Before introducing a large new language concept, check the implemented feature docs and current v0 decisions. Eido intentionally defers some familiar features when the semantic model is not yet justified by real usage.
