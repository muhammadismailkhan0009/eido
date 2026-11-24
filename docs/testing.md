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
    diagnostics/

    features/
      expression/
      classes/
      control_flow/
      native/
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

### Structured diagnostic tests

`compiler/tests/diagnostics/` proves stable diagnostic codes, severity/message/span preservation, project diagnostics without spans, human rendering, and the protocol-neutral `ProjectCheckResult` contract used by CLI/LSP/MCP/CI.

`compiler/tests/tooling/` proves protocol-neutral semantic editor queries such as typed HIR hover without involving an editor protocol. `tests/integration/lsp_server_test.nim` proves LSP initialization, full-document overlays, live diagnostics, hover responses, and JSON-RPC framing over the thin adapter.

### Language feature tests

`compiler/tests/features/` is the executable catalog of user-visible Eido behavior.

These tests answer questions such as:

- do 0-, 1-, 2-, and N-parameter functions work?
- which parameter-count/result-count combinations have been exercised?
- which primitive types have been exercised through real Eido programs?
- which variable initialization/`set` mutation variants work?
- which expression forms work?
- are self-free class functions inferred static and callable only as `Type.method(...)`?
- do self-dependent class functions remain receiver-bound instance methods?
- do class-owned native functions stay bodyless/static and call backend support without an Eido wrapper body?
- are class-valued native ABI inputs/results still rejected?

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
- Feature tests exercise complete user-facing Eido variants through generated Nim. The helper uses `nim e` when supported and native compilation when generated programs import native Storage support (which the Nim VM cannot execute). Compatible successful scenarios may be batched into one compiled executable.
- Architecture tests prove dependency/readability/test-organization constraints.
- Root integration tests prove cross-component flows such as CLI multi-source project builds, semantic-only `eido check`, and compilation/execution of permanent Eido-written tooling.
- Test through public phase entry points; do not test private procedures directly.

## Test support

`compiler/tests/support/compiler_test_support.nim` exposes concise real-phase entry points such as source → AST, source → HIR, and source → Nim.

`compiler/tests/support/feature_test_support.nim` runs complete Eido programs through the Eido compiler and executes generated Nim with `nim e` where compatible. When the emitted program depends on native Storage support or managed runtime operations, it compiles and executes a native program. Native code generation also has dedicated tests under `compiler/tests/pipeline/`.

`compiler/tests/support/feature_batch_support.nim` batches *successful* Eido feature scenarios: it compiles each Eido fixture independently, wraps each generated Nim entrypoint as an exported module callable, then compiles and runs one combined native executable (or one Nim VM program if every module is VM-compatible). Captured per-case stdout is compared against separate expectations with each scenario name recorded using `checkpoint`. Expected crashes/failed runtime contracts must remain independent subprocess tests; compiler rejection tests remain ordinary compiler tests. The batch runner is test infrastructure and does not change production Eido code generation.

Test support must not duplicate compiler logic or become a generic utilities directory.

## Package-owned Eido tests

Reusable Eido packages keep executable tests under `<package>/tests/module.yaml`. Production modules do not depend on their tests or on `packages/testing`.

Run one package test module with:

```text
eido test <package-directory>
```

Use `--memory=<policy>` when the same tests should execute under another memory policy.

## Running tests

Run the complete compiler + feature + integration suite with:

```text
nimble test
```

The canonical test task is parallel and CPU-adaptive:

1. The runner discovers compiler suites and individual feature selectors, compiles the aggregate once, and runs independent processes.
2. The default worker count is half the logical CPUs (at least one). `EIDO_TEST_JOBS` may explicitly raise concurrency to the detected logical processor count. Aggregate compilation uses the same worker limit.
3. Selectors are ordered by previously observed durations, longest first; timings are scheduling hints only. Unknown selectors use deterministic alphabetical order.
4. Each child writes to a separate temporary log, preventing output-pipe backpressure. Successful logs are suppressed, failed logs are replayed, and periodic progress identifies active tests.
5. The four cross-component integration suites run in parallel as a separate stage after the compiler/feature pool drains.
6. Compatible successful cases share one native compilation or Nim VM invocation; expected crashes remain isolated. Case names and expected results remain individually checked.

```bash
nimble test
EIDO_TEST_JOBS=4 nimble test
EIDO_TEST_FILTER='While execution' nimble test
EIDO_TEST_NO_CACHE=1 nimble test
```

The filter is a case-insensitive substring of selector names. Without a filter, all selectors and integration suites execute. The default worker count is intentionally conservative because native compiler subprocesses also consume CPU resources.

The executable pipeline validates the full source project, then removes unreachable declarations before code generation. Pure arithmetic, control flow and Alignment-only programs no longer pull in the native Storage SDK; compatible feature fixtures execute through the Nim VM. The compiler retains native execution for real Storage, managed objects and String support.

Native feature tests cache compiled executables by generated Nim source, all batch modules, SDK native support, compiler invocation and ordinary toolchain/configuration identity. Every run still compiles Eido to Nim and executes the resulting program; assertions/results are never cached. Dedicated native-toolchain tests still compile directly. Custom compiler/SDK overrides bypass the feature artifact cache; `EIDO_TEST_NO_CACHE=1` requests fresh native feature compilation. This local development cache is not a hermetic build-system cache for arbitrary external toolchain configuration. The cache is under the Eido user cache directory (typically `~/.cache/eido/native-feature-tests` on Linux).

Independent native application builds use Nim object caches scoped by full generated-source/output paths, not module basename. Native batches use temporary, isolated Nim object directories. Embedded native support is content-versioned and atomically published.

The runner prints aggregate build time, execution time, active selectors, completion counts, and a final failure summary.
