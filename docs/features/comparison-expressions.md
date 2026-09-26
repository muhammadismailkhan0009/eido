# Comparison expressions

Eido supports equality and ordered comparison as Bool-producing expressions.

## Operators

Equality comparisons:

```text
==
!=
```

Ordered comparisons:

```text
<
<=
>
>=
```

Every comparison produces `Bool`.

## Equality

`==` and `!=` accept operands of the same primitive type:

```text
true == false
tiny != otherTiny
count == otherCount
ratio != otherRatio
'A' == marker
```

There is no implicit cross-type primitive conversion. For example, `1 == 1.0`
is rejected because the operands are Int and Float.

An integer literal may adopt the integral type of the opposite operand when that
operand is Byte or Short. Therefore, if `tiny` is Byte, `tiny == 7` and
`7 == tiny` both compare Byte values.

## Ordered comparison

`<`, `<=`, `>`, and `>=` accept matching numeric operands:

```text
Byte
Short
Int
Float
```

Bool and Char do not support ordering.

As with equality, ordered comparison does not introduce numeric promotion.
`1 < 2.0` is rejected. Integer literals may still be contextually typed from
an opposite Byte or Short operand.

## Precedence

The current expression precedence from highest to lowest is:

```text
grouping () [] {}
unary -
* /
+ -
< <= > >=
== !=
```

Thus:

```text
1 + 2 < 4 * 2
```

compares `3` with `8`, and:

```text
1 < 2 == true
```

first evaluates `1 < 2`, then compares that Bool result with `true`.

Comparisons associate left-to-right at their own precedence level. A chained
ordered comparison such as `1 < 2 < 3` is therefore rejected semantically:
the first comparison produces Bool, which cannot participate in the second
ordered comparison.
