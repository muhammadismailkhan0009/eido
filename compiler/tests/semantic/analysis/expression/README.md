# Expression semantic-analysis tests

These tests mirror `compiler/src/semantic/analysis/expression/` and prove
expression typing/resolution at the smallest useful semantic boundary.

- `literal_expression_analysis_test.nim` — default primitive literal typing
- `expected_type_analysis_test.nim` — contextual integral literals and expected-type validation
- `identifier_expression_analysis_test.nim` — identifier resolution failures
- `call_expression_analysis_test.nim` — function resolution, arity, arguments, and value-call rules
- `unary_negation_analysis_test.nim` — Int/Float unary negation restrictions
- `arithmetic_operator_analysis_test.nim` — matching Int/Float arithmetic
- `comparison_operator_analysis_test.nim` — equality/ordered comparison typing
- `boolean_operator_analysis_test.nim` — Bool-only `not/and/or`

Declaration ordering, local uniqueness/reassignment, and function result/body
contracts remain in their own semantic suites because those are not expression
responsibilities.
