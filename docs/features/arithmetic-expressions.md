# Arithmetic expressions

Eido keeps built-in arithmetic deliberately small.

## Operators

Binary arithmetic stays deliberately small:

```text
/
*
+
-
```

Eido also supports unary numeric negation:

```text
-value
-(a + b)
```

Unary `-` is valid for Int and Float. Byte, Short, Bool, and Char do not
currently participate in unary arithmetic.

Derived mathematical operations such as powers, roots, logarithms, and
trigonometric functions belong in libraries rather than the language core.

## Precedence

Within arithmetic, precedence is:

```text
highest: grouping () [] {}
         unary -
         * /
lowest:  + -
```

Comparison operators bind below arithmetic; see `comparison-expressions.md` for the complete current expression precedence.

Unary `-` binds to the following unary/primary expression. Binary operators
on the same level are evaluated left-to-right.

Therefore:

```text
10 + 20 * 3      == 70
20 / 5 * 2       == 8
10 - 3 + 2       == 9
```

## Grouping delimiters

All three mathematical grouping forms are accepted in expressions:

```text
(...)
[...]
{...}
```

They are semantically equivalent. The delimiter shape does not introduce a
different precedence level; the innermost grouped expression is evaluated
first, and any grouped expression binds more tightly than DMAS operators.

Examples:

```text
(10 + 20) * 3
[10 + 20] * 3
{10 + 20} * 3
```

all evaluate to `90`.

Mixed nesting is valid:

```text
[{(10 + 20) * 2} + 5] * 2
```

Delimiter pairs must match exactly. For example, `[1 + 2)` is invalid.

Curly braces remain function-body delimiters in declaration/body grammar and
act as arithmetic grouping only where an expression is expected.


## Unary negation examples

```text
-2 * 3       == -6
-(2 * 3)     == -6
--5           == 5
10 - -5       == 15
```

Unary minus is an expression operator, not part of the numeric token itself.
Thus `-value`, `-result()`, and `-(a + b)` use the same language rule.
