# Expression semantic-analysis ownership

`../expression_analysis.nim` is the public semantic coordinator. It exposes
`analyzeExpr` and `analyzeExprExpected`, then delegates expression behavior
to focused modules in this directory.

## Modules

- `literal_expressions.nim` — primitive literal typing and integral range checks
- `expected_types.nim` — expected-type validation and contextual Byte/Short/Int literal typing
- `identifier_expressions.nim` — local/parameter identifier resolution
- `call_expressions.nim` — function resolution, arity, argument typing, and value-call rules
- `class_value_relations.nim` — explicit `copy`/`ref` validation and existing/detached class provenance
- `construction_expressions.nim` — exact-field nominal construction semantics and explicit identity choice for existing class-valued inputs
- `field_access_expressions.nim` — nominal receiver/field resolution and result typing
- `method_call_expressions.nim` — nominal receiver/method resolution, arity, argument, and result typing
- `unary_negation.nim` — Int/Float unary negation semantics
- `arithmetic_operators.nim` — matching Int/Float arithmetic semantics
- `comparison_operators.nim` — equality, ordering, and comparison literal contextual typing
- `boolean_operators.nim` — Bool-only `not`, `and`, and `or` semantics

The coordinator should contain dispatch and public API declarations, not
feature-specific type rules.

## Test mirror

Compiler semantic tests for these rules live under:

```text
tests/compiler/semantic/analysis/expression/
```

Function-level and scope/declaration rules remain in their owning function or
local-binding suites even when they contain expressions.
