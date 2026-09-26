# Expression parser ownership

`../expression_parser.nim` is the public coordination hub. It owns the shared
`parseExpression` entry point and the small binary-span helper; semantic parsing
behavior lives here.

## Modules

- `literal_expressions.nim` — Int, Float, Bool, and Char literals
- `call_expressions.nim` — function-call expressions and argument parsing
- `grouping_expressions.nim` — `()`, `[]`, and `{}` grouping/matching
- `primary_expressions.nim` — primary-expression dispatch and identifiers
- `unary_negation.nim` — recursive numeric unary `-`
- `arithmetic_operators.nim` — `* / + -`
- `comparison_operators.nim` — `< <= > >= == !=`
- `boolean_operators.nim` — `not and or`

## Precedence

Highest to lowest:

```text
primary / grouping
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
