# Eido testing strategy

Eido uses behavior-driven development with two complementary test layers:

1. compiler-internal responsibility tests;
2. language-facing feature acceptance tests.

## BDD lifecycle

For new or changed language behavior:

1. State the observable behavior before implementation.
2. Write the smallest Given–When–Then scenario at the boundary that owns it.
3. Run the scenario and confirm it fails for the intended missing behavior.
4. Implement the minimum production change.
5. Run the focused scenario until it passes.
6. Refactor without changing behavior.
7. Add/update the language-facing feature variant when the behavior is user-visible.
8. Run the full suite with `nimble test`.

For behavior-preserving refactors, add or confirm characterization scenarios first.
Do not manufacture an artificial failing test when the behavior already exists.

## Test organization

```text
tests/
  compiler/
    architecture/
    frontend/lexer/
    frontend/parser/
    semantic/analysis/
    backend/nim/emitter/
    pipeline/

  features/
    expression_variants_test.nim
    function_variants_test.nim
    primitive_variants_test.nim
    variable_variants_test.nim

  support/
  compiler_test_suite.nim
```

### Compiler-internal tests

`tests/compiler/` mirrors production responsibilities.

These tests answer questions such as:

- did the lexer classify this token correctly?
- did the parser build the intended AST?
- did semantic analysis resolve/type-check this program correctly?
- did HIR lower to the expected Nim representation?

### Language feature tests

`tests/features/` is the executable catalog of user-visible Eido behavior.

These tests answer questions such as:

- do 0-, 1-, 2-, and N-parameter functions work?
- which parameter-count/result-count combinations have been exercised?
- which primitive types have been exercised through real Eido programs?
- which variable initialization/reassignment variants work?
- which expression forms work?

Some behavior is intentionally covered by both layers because the boundary risk is different:
the compiler test proves the owning implementation contract, while the feature test proves the language surface as a complete Eido program.

Do not create historical milestone suites such as `test_feature06.nim`. Feature acceptance files are named for the language capability, not the chronological feature number.

## Scenario style

Each test proves one behavior and uses explicit sections:

```nim
test "2 params + 1 result: function can combine both arguments":
  # Given
  let source = "..."

  # When
  let output = runNativeSource(source, "function_2p_1r")

  # Then
  check output == "30"
```

Names describe visible behavior rather than implementation details.

## Boundary rules

- Lexer/parser tests prove syntax/token/AST behavior.
- Semantic-analysis tests prove name resolution, typing, contracts, and HIR meaning.
- Backend tests prove HIR-to-Nim translation.
- Pipeline tests exercise the complete real path through the Nim toolchain.
- Feature tests exercise complete user-facing Eido variants and serve as the readable capability catalog.
- Architecture tests prove dependency/readability/test-organization constraints.
- Test through public phase entry points; do not test private procedures directly.

## Test support

`tests/support/compiler_test_support.nim` exposes concise real-phase entry points such as source → AST, source → HIR, and source → Nim.

`tests/support/native_test_support.nim` compiles and executes complete Eido programs for feature acceptance tests.

Test support must not duplicate compiler logic or become a generic utilities directory.

## Running tests

Run the complete internal + feature suite with:

```text
nimble test
```
