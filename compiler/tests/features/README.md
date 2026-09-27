# Eido language feature tests

This directory is the executable, user-facing catalog of currently supported Eido behavior.

These tests answer:

> Which language variants have actually been exercised as Eido programs?

They complement `compiler/tests/`, which tests lexer/parser/semantic/backend responsibilities internally.

## Feature catalogs

Files are broad navigation boundaries; suites inside them name the smallest useful semantic group.

- `expression/` — expression-family catalogs split into arithmetic, grouping, unary negation, comparisons, and Boolean operators; start with `expression/README.md` for the coverage matrix and known gaps
- `classes/` — nominal class declarations, class-type resolution, and named construction; start with `classes/README.md`
- `control_flow/` — conditionals, `else if` chains, `while`/classic `for` loops, `break`/`continue`, structured scope isolation, and return-path coverage; start with `control_flow/README.md`
- `function_variants_test.nim` — signature cardinality, zero-result returns, call resolution/arity, and result contracts
- `native/` — top-level and class-owned `native function` execution through the bundled backend-support ABI; start with `native/README.md`
- `primitive_variants_test.nim` — supported primitive values, Byte bounds, numeric suffix rejection, and removed numeric type names
- `string_variants_test.nim` — built-in immutable String literals, signatures, concatenation/equality, class storage, replacement through `set`, and binding/copy-ref boundaries
- `variable_variants_test.nim` — initialization forms, `set` mutation forms, declaration ordering, and declaration uniqueness

## Function matrix

The function suite explicitly exercises:

| Inputs | No result | One result |
| --- | --- | --- |
| 0 params | yes | yes |
| 1 param | yes | yes |
| 2 params | yes | yes |
| N params (12 in the test) | yes | yes |

It also covers:

- empty no-result body
- explicit `return;`
- forward calls
- wrong arity rejection
- missing required result rejection
- returning a value from a no-result function rejection

## Style

Feature tests should use Eido source as the primary test fixture and describe language behavior in their test names.

A suite must name one narrow semantic rule or variant family, not the broad file category. For example, keep `Binary operator precedence`, `Grouping delimiter equivalence`, and `Unary negation binding` as separate suites inside the expression catalog instead of one `Expression feature variants` suite.

Prefer:

`2 params + 1 result: function can combine both arguments`

over:

`test function parser case 7`

Successful variants should normally run through the full Eido compiler to generated Nim and execute with `nim e` when an observable result is available. Dedicated compiler-pipeline tests retain real native-compilation coverage. Rejection variants may stop at semantic analysis when execution is not meaningful.

Do not organize these tests by historical milestone number. Add a scenario to the file for the language feature it demonstrates.

Run everything with:

`nimble test`
