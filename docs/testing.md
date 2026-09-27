# Eido testing strategy

Eido uses behavior-driven development with three complementary test layers:

1. compiler-internal responsibility tests;
2. language-facing feature acceptance tests;
3. cross-component toolchain integration tests.

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
compiler/
  tests/
    architecture/
    frontend/lexer/
      keywords/
    frontend/parser/
      expression/
      statement/
    semantic/analysis/
      expression/
      statement/
    backend/nim/emitter/
      expression/
      statement/
    pipeline/
    project/

    features/
      expression/
      classes/
      control_flow/
      function_variants_test.nim
      primitive_variants_test.nim
      string_variants_test.nim
      variable_variants_test.nim
      set_variants_test.nim

    support/
    compiler_test_suite.nim
    parallel_test_runner.nim

tests/
  integration/   # cross-component SDK/tooling/library tests
```

### Compiler-internal tests

`compiler/tests/` mirrors production responsibilities. Expression parser/analysis tests mirror their focused expression modules, while structured statement features such as conditionals and loops mirror the focused `statement/` modules across parser, semantic analysis, and emitter layers.

These tests answer questions such as:

- did the lexer classify this token correctly?
- did the parser build the intended AST?
- did semantic analysis resolve/type-check this program correctly?
- did HIR lower to the expected Nim representation?

### Project/compiler tests

`compiler/tests/project/` proves project-source assembly, executable/library target rules, source-order independence, and source-aware diagnostics without involving editor/MCP transports.

### Language feature tests

`compiler/tests/features/` is the executable catalog of user-visible Eido behavior.

These tests answer questions such as:

- do 0-, 1-, 2-, and N-parameter functions work?
- which parameter-count/result-count combinations have been exercised?
- which primitive types have been exercised through real Eido programs?
- which variable initialization/`set` mutation variants work?
- which expression forms work?

Some behavior is intentionally covered by multiple layers because the boundary risk is different: compiler tests prove the owning implementation contract, feature tests prove the language surface as complete Eido programs, and root integration tests prove adapters/tooling compose those compiler capabilities correctly.

Do not create historical milestone suites such as `test_feature06.nim`. Feature acceptance files are named for the language capability, not the chronological feature number.

## Scenario style

Each test proves one behavior and uses explicit sections:

```nim
test "2 params + 1 result: function can combine both arguments":
  # Given
  let source = "..."

  # When
  let output = runFeatureSource(source, "function_2p_1r")

  # Then
  check output == "30"
```

Names describe visible behavior rather than implementation details.

## Boundary rules

- Lexer/parser tests prove syntax/token/AST behavior.
- Semantic-analysis tests prove name resolution, typing, contracts, and HIR meaning.
- Backend tests prove HIR-to-Nim translation.
- Pipeline tests exercise the complete real path through native Nim compilation.
- Feature tests exercise complete user-facing Eido variants through generated Nim executed by `nim e`; this preserves end-to-end language behavior without paying native compilation cost per scenario.
- Architecture tests prove dependency/readability/test-organization constraints.
- Root integration tests prove cross-component flows such as CLI multi-source project builds through the real native toolchain.
- Test through public phase entry points; do not test private procedures directly.

## Test support

`compiler/tests/support/compiler_test_support.nim` exposes concise real-phase entry points such as source → AST, source → HIR, and source → Nim.

`compiler/tests/support/feature_test_support.nim` runs complete Eido programs through the Eido compiler and executes the generated Nim with the Nim VM (`nim e`). Native code generation remains covered separately by `compiler/tests/pipeline/`.

Test support must not duplicate compiler logic or become a generic utilities directory.

## Running tests

Run the complete compiler + feature + integration suite with:

```text
nimble test
```

The canonical test task is parallel and CPU-adaptive:

1. `compiler/tests/parallel_test_runner.nim` discovers static unittest suites/tests.
2. The complete `compiler/tests/compiler_test_suite.nim` aggregate is compiled once.
3. Aggregate compilation uses `--parallelBuild:N`, where `N` is the effective worker count after reserving two logical cores by default.
4. Compiler-internal tests run one process per suite.
5. Language-facing feature tests run one process per individual test, because those cases are comparatively expensive and often execute generated Nim through `nim e`.
6. Independent selectors execute with `std/osproc.execProcesses` using the same worker count.
7. Successful child output is suppressed; failed child output is replayed with its selector.
8. After the parallel compiler/language aggregate succeeds, root `tests/integration/` suites run cross-component toolchain scenarios; currently this includes multi-source CLI parsing/build/native execution.

Worker count defaults to `max(1, countProcessors() - 2)` so two logical cores remain free for the OS and other work. Override it when needed:

```text
EIDO_TEST_JOBS=4 nimble test
```

The override controls both aggregate build parallelism and test-process concurrency.

The runner uses process isolation rather than threads so `std/unittest` fixtures and compiler/native-toolchain subprocesses remain independent.
