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
Eido source
    ↓
lexer
    ↓
parser
    ↓
AST
    ↓
semantic analysis
    ↓
typed + resolved HIR
    ↓
Nim emitter
    ↓
generated Nim
    ↓
Nim toolchain
    ↓
native executable
```

## Ownership

```text
compiler/source/
    source locations shared across compiler phases

compiler/diagnostics/
    compiler error formatting and reporting helpers

compiler/frontend/lexer/
    token model, keyword recognition, source scanning

compiler/frontend/ast/
    syntax tree grouped by expressions, statements, declarations, program

compiler/frontend/parser/
    parser mechanics and grammar grouped by construct
    expression_parser.nim is a thin expression-entry/precedence coordinator
    expression/ groups literals, calls, grouping, unary negation, arithmetic,
    comparisons, and Boolean operators by semantic ownership

compiler/types/
    core Eido semantic type model

compiler/semantic/symbols/
    symbol identity, function symbols, and lexical local scopes

compiler/semantic/analysis/
    type resolution plus expression, statement, function, and program semantic passes

compiler/hir/
    resolved and typed compiler representation

compiler/backend/nim/emitter/
    pure HIR → Nim source translation

compiler/backend/nim/toolchain/
    generated artifacts and Nim process invocation

compiler/pipeline/
    pure compiler-stage orchestration

cli/
    command parsing and build-file orchestration
```

## Dependency rules

- Source and diagnostic concepts must not depend on parser, semantic, HIR, backend, toolchain, or CLI code.
- Frontend code must not depend on semantic analysis, HIR, or backend code.
- Semantic analysis may consume AST and produce HIR.
- HIR must contain resolved symbol identity and semantic types needed by backends.
- Backends consume HIR, not raw AST.
- The Nim emitter must not perform Eido name resolution or type checking.
- Nim-specific types, names, process execution, and artifact paths must not leak into Eido semantic types or AST.
- Filesystem and process execution stay in the outer toolchain/CLI boundary.
- Dependencies must remain acyclic.

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
