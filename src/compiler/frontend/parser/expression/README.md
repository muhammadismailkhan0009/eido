# Expression parser ownership

`../expression_parser.nim` is the public coordination hub. It owns the shared
`parseExpression` entry point and the small binary-span helper; semantic parsing
behavior lives here.

## Modules

- `literal_expressions.nim` — Int, Float, Bool, and Char literals
- `call_expressions.nim` — shared call-argument parsing and top-level function calls
- `construction_expressions.nim` — named class construction expressions
- `field_access_expressions.nim` — postfix `.field` access and `.method(...)` instance-call chains
- `grouping_expressions.nim` — `()`, `[]`, and `{}` grouping/matching
- `primary_expressions.nim` — primary-atom dispatch, explicit `self`, parsed `copy`/`ref` relation prefixes, plus postfix access application
- `unary_negation.nim` — recursive numeric unary `-`
- `arithmetic_operators.nim` — `* / + -`
- `comparison_operators.nim` — `< <= > >= == !=`
- `boolean_operators.nim` — `not and or`

## Precedence

Highest to lowest:

```text
primary / grouping / construction
postfix field access
unary -
* /
+ -
< <= > >=
== !=
not
and
or
```

When a new expression family becomes independently meaningful, give it a focused
module here rather than growing `expression_parser.nim`.
