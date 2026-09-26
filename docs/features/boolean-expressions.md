# Boolean expressions

Eido uses word operators for Boolean logic:

```text
not
and
or
```

Symbolic forms such as `!`, `&&`, and `||` are not Boolean operators in Eido.

## Types

All Boolean operators work only with `Bool` values.

```text
not false
ready and valid
cached or available
```

`not` accepts one Bool and returns Bool. `and` and `or` each accept two
Bool operands and return Bool. Eido does not implicitly convert numeric,
character, or other primitive values to Bool.

## Short circuiting

`and` and `or` short-circuit:

- `false and expression` does not evaluate `expression`.
- `true or expression` does not evaluate `expression`.

This makes guarded Boolean expressions safe to compose without evaluating a
right-hand branch that is already irrelevant to the result.

## Precedence

The current expression precedence from highest to lowest is:

```text
grouping () [] {}
unary -
* /
+ -
< <= > >=
== !=
not
and
or
```

The word `not` deliberately binds below comparison and equality operators.
Therefore:

```text
not age < 18
```

means:

```text
not (age < 18)
```

rather than `(not age) < 18`.

`not` still binds more tightly than `and`, and `and` binds more tightly
than `or`. Thus:

```text
not expired and active or admin
```

groups as:

```text
((not expired) and active) or admin
```
