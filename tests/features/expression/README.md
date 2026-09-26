# Expression feature coverage

This directory is the user-facing acceptance catalog for Eido expression behavior.
The files are split by semantic family so missing variants are visible without
searching through one large expression test file.

## Ownership

| Expression family | Feature coverage |
| --- | --- |
| Primitive literals | `../primitive_variants_test.nim` |
| Function-call expressions | `../function_variants_test.nim` |
| Identifier/local expressions | `../variable_variants_test.nim` and function parameter/result scenarios |
| Grouping | `grouping_variants_test.nim` |
| Unary numeric negation | `unary_negation_variants_test.nim` |
| Arithmetic | `arithmetic_variants_test.nim` |
| Comparisons | `comparison_variants_test.nim` |
| Boolean word operators | `boolean_operator_variants_test.nim` |

Parser implementation ownership is documented in
`src/compiler/frontend/parser/expression/README.md`. This catalog tracks
observable language behavior rather than duplicating parser-internal boundaries.

## Arithmetic coverage

| Variant | Int | Float |
| --- | --- | --- |
| `+` | yes | yes |
| `-` | yes | **missing direct feature case** |
| `*` | yes | **missing direct feature case** |
| `/` | yes | yes |

Also covered:

- multiplicative precedence over additive operators
- left-to-right associativity at equal precedence

## Grouping coverage

| Variant | Status |
| --- | --- |
| `(...)` overrides normal precedence | yes |
| `[...]` overrides normal precedence | yes |
| `{...}` overrides normal precedence | yes |
| mixed nested delimiter forms | yes |
| delimiter forms have equivalent grouping power | yes |

Mismatched delimiter rejection is currently proven at the parser/compiler-test
layer rather than as a language-facing feature scenario.

## Unary negation coverage

| Variant | Status |
| --- | --- |
| Int operand | yes |
| Float operand | yes |
| variable operand | yes |
| call-result operand | yes |
| grouped operand | yes |
| recursive/double negation | yes |
| Byte rejected | yes |
| Short rejected | yes |
| Bool rejected | yes |
| Char rejected | yes |
| binds before multiplication | yes |
| subtraction followed by unary minus | yes |

## Comparison coverage

Equality acceptance currently has direct feature cases for:

- Int `==`
- Bool `!=`
- Char `==`

Ordered comparison currently has direct feature cases for:

- Byte `<`
- Short `<=`
- Int `>`
- Float `>=`

Also covered:

- mismatched primitive equality rejection
- Bool ordered-comparison rejection
- arithmetic binding before ordered comparison
- ordered comparison binding before equality

This intentionally exposes that the complete type/operator cross-product is not
yet represented by language-facing feature cases.

## Boolean coverage

| Variant | Status |
| --- | --- |
| `not` | yes |
| `and` | yes |
| `or` | yes |
| comparison binds inside `not` | yes |
| `and` binds before `or` | yes |
| `and` short-circuits | yes |
| `or` short-circuits | yes |
| symbolic `!`, `&&`, `||` rejected | yes |

Bool-only type restrictions are additionally proven at the semantic-analysis
test layer.

## Cross-catalog expression coverage

Some expression forms are better owned by another user-facing feature catalog:

- Primitive literal values and Byte bounds: `../primitive_variants_test.nim`
- Function calls, arity, forward resolution, and returned call values:
  `../function_variants_test.nim`
- Local identifier reads and computed expressions: `../variable_variants_test.nim`

When adding a new expression family, add a focused file here unless another
feature catalog clearly owns its observable semantics. Update this coverage
index whenever a case is added, removed, or deliberately deferred.
