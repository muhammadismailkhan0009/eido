# Eido language feature tests

This directory is the executable, user-facing catalog of currently supported Eido behavior.

These tests answer:

> Which language variants have actually been exercised as Eido programs?

They complement `tests/compiler/`, which tests lexer/parser/semantic/backend responsibilities internally.

## Feature catalogs

Files are broad navigation boundaries; suites inside them name the smallest useful semantic group.

- `function_variants_test.nim` — signature cardinality, zero-result returns, call resolution/arity, and result contracts
- `primitive_variants_test.nim` — supported primitive values, Byte bounds, numeric suffix rejection, and removed numeric type names
- `variable_variants_test.nim` — initialization forms, reassignment forms, declaration ordering, and declaration uniqueness
- `expression_variants_test.nim` — arithmetic, grouping, unary negation, equality/ordered comparisons, comparison type compatibility, and expression binding

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

Successful variants should normally compile through the real native pipeline when an observable result is available. Rejection variants may stop at semantic analysis when native compilation is not meaningful.

Do not organize these tests by historical milestone number. Add a scenario to the file for the language feature it demonstrates.

Run everything with:

`nimble test`
