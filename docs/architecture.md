# Eido compiler architecture

Eido uses a modular compiler architecture with onion-style dependency boundaries.

## Unit of organization

- Directories represent compiler capabilities.
- Files represent cohesive parts of a capability.
- Procedures represent individual operations.
- Do not create one file per procedure.
- Do not allow one phase file to accumulate unrelated responsibilities.
- Do not create empty architectural directories in anticipation of future features.

## Current pipeline

```text
EidoProject
    ↓
SourceUnit[]
    ↓
per-source lexer + parser
    ↓
merged project AST declaration universe
    ↓
generic-class static specialization
    ↓
target-aware semantic analysis
    ↓
typed + resolved HIR
    ↓
Nim emitter
    ↓
generated Nim
    ↓
Nim toolchain
    ↓
native executable (executable target)
```

Single-source compilation remains a convenience wrapper that constructs a one-source executable project.

## Ownership

```text
compiler/src/source/
    SourceUnit identity/text and source-aware spans shared across compiler phases

compiler/src/project/
    EidoProject source set and executable/library target model

compiler/src/diagnostics/
    structured diagnostic model/codes, CompilerError bridge, and human formatting

compiler/src/frontend/
    lexer, AST, and parser capabilities

compiler/src/types/
    core Eido semantic type model

compiler/src/semantic/
    symbol identity, name resolution, type analysis, and statement/expression semantics

compiler/src/hir/
    resolved and typed compiler representation

compiler/src/backend/nim/emitter/
    pure HIR → Nim source translation

compiler/src/backend/nim/toolchain/
    generated artifacts, Nim process invocation, and backend native-support path resolution

compiler/src/pipeline/
    single-source compatibility plus project parse/analyze/emit orchestration

compiler/src/tooling/
    protocol-neutral project check/compile services exposed to CLI, MCP, LSP, CI, and agents

compiler/tests/
    compiler-internal and language-facing conformance tests

tools/cli/src/
    temporary Nim bootstrap command parsing and build/check orchestration

tools/cli/eido/
    permanent CLI implementation written in Eido and compiled by the bootstrap compiler

tools/mcp/
    MCP protocol adapter over compiler tooling; semantic logic does not live here

tools/lsp/
    language-server adapter over compiler tooling; editor semantics do not live here

stdlib/src/
    ordinary Eido-facing foundational APIs

stdlib/native/
    backend-specific implementation support used by explicit Eido native declarations

packages/
    higher-level ordinary Eido libraries built above stdlib

installer/
    SDK assembly and installation logic

tests/integration/
    cross-component SDK/tool/library integration tests
```

## Dependency rules

- Source and diagnostic data concepts must not depend on parser, semantic, HIR, backend, toolchain, or CLI code. Diagnostic errors/formatting may depend only on source + diagnostic model/codes.
- Frontend code must not depend on semantic analysis, HIR, or backend code.
- Project/source identity models are lower-level compiler data and may be consumed by frontend, semantic, pipeline, and tooling layers.
- Each SourceUnit is parsed independently, but semantic analysis consumes the merged project declaration universe so source order does not define visibility.
- Semantic analysis may consume AST and produce HIR.
- Generic class applications are statically specialized from AST templates into concrete nominal AST classes before ordinary semantic declaration/body analysis. HIR carries no unresolved generic class parameters in this first slice.
- Optionality is semantic state, not a source-level wrapper API. `T?` remains explicit through semantic types/HIR; `if path exists` introduces an exact lexical presence proof, and HIR inserts backend unwrap nodes only at proven reads. The Nim backend currently represents optionals with `Option[T]`, but Eido semantics do not depend on Nim's representation.
- HIR must contain resolved symbol identity and semantic types needed by backends. Class-owned functions also carry resolved `mkStatic`/`mkInstance` kind: only instance-method HIR variants may contain a receiver ID/value, so backends/tooling cannot accidentally invent receivers for inferred static methods.
- Backends consume HIR, not raw AST.
- The Nim emitter must not perform Eido name resolution, type checking, or static/instance inference. Semantic analysis classifies Eido-bodied class functions from explicit `self` dependency before HIR; bodyless class-owned native functions are explicitly resolved as `mkStatic`. The emitter only obeys resolved method kind/native-ness.
- Nim-specific types, names, process execution, artifact paths, and native-support module layout must not leak into Eido semantic types or AST.
- `native function` is an explicit language boundary: semantic analysis validates only its Eido-visible signature, while backend symbol/provider mechanics remain backend support concerns. Native declarations may be top-level or class-owned; class-owned native declarations are resolved as static/type-associated methods with no receiver and no Eido body.
- The initial native ABI accepts primitives/String only. Class values remain forbidden until a deliberate cross-native identity/representation/lifetime model exists. Native instance methods are also deferred because they would require passing Eido object identity across the native boundary.
- `compiler/src/tooling/` may coordinate stable compiler capabilities, but it must not depend on MCP, LSP, editor, or vendor-specific protocol code.
- Protocol adapters under `tools/` consume compiler tooling services; compiler semantic phases must not depend on those adapters.
- Expected user compiler failures are represented as structured `CompilerDiagnostic` values and may cross phase boundaries through `CompilerError`; adapters must not recover semantic facts by parsing human exception strings.
- `checkProject` performs parser + semantic work only and does not invoke HIR emission/backend compilation; unexpected compiler invariant failures remain exceptional rather than being mislabeled as user diagnostics.
- Filesystem and process execution stay in the outer backend-toolchain/tool-adapter boundary.
- Dependencies must remain acyclic.

## Requirement-driven ecosystem growth

Ordinary ecosystem software should be written in Eido once the language can express it cleanly. Development proceeds vertically from permanent product needs:

```text
real tool requirement
        ↓
classify missing capability
        ↓
language / stdlib / package / compiler tooling / native support
        ↓
implement + test at owning layer
        ↓
consume immediately in the permanent Eido-written tool
```

The reference compiler/core may remain Nim. Temporary Nim adapters are bootstrap infrastructure, not the desired permanent home for CLI/LSP/MCP/formatter/package-manager logic.

The first permanent dogfood target is `tools/cli/eido/main.eido`; the bootstrap Nim CLI remains until the Eido CLI reaches feature parity.

## Growth rule

When a capability grows, split by semantic ownership inside its existing area rather
than allowing a generic hub file to accumulate feature-specific behavior. Stable hub
modules should coordinate shared dispatch and entry points; independently meaningful
families belong in focused subdirectories.

For example, Boolean expression behavior lives under the expression areas for lexer
keywords, parsing, semantic analysis, emission, and tests. This does not imply one
file per token or operator: compact canonical vocabularies such as token and AST/HIR
operator enums remain centralized while they are still cohesive.

Create nested directories when they reduce navigation cost by grouping meaningful
behavior families, not merely to reduce line counts or manufacture folder depth.

## Readability rule

Every procedure must have a brief Nim documentation comment directly above it that says what the procedure does and gives a small concrete example. Capability files should also begin with a short module-level comment explaining their role with an example. Comments should explain compiler meaning, especially for abstract concepts such as symbols, scopes, IDs, AST, and HIR; do not merely restate the procedure name.

## Testing rule

Tests mirror compiler responsibilities rather than historical feature numbers.
New behavior is developed BDD-first: write the owning Given–When–Then scenario,
confirm the intended failure, implement the minimum behavior, then run broader
checks. Behavior-preserving refactors use characterization scenarios rather than
artificial failures.

Parser, semantic-analysis, backend, architecture, and full native-pipeline tests
remain separate so each behavior is proven at the smallest useful boundary.
See `docs/testing.md` for the complete test strategy. Generated Nim is retained
during compiler development for backend inspection.
