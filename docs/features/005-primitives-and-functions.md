# Primitive types and complete basic functions

Eido defines a deliberately small primitive family and a basic function model
with zero-or-more inputs and zero-or-one result.

## Primitive types

| Eido | Meaning | Nim backend |
| --- | --- | --- |
| `Bool` | logical true/false | `bool` |
| `Byte` | signed 8-bit integer | `int8` |
| `Short` | signed 16-bit integer | `int16` |
| `Int` | signed 64-bit integer | `int64` |
| `Float` | 64-bit floating point | `float64` |
| `Char` | unsigned 16-bit character/code unit | `uint16` |

Eido intentionally does not split ordinary integer work between `Int` and
`Long`, or ordinary floating-point work between `Float` and `Double`.
There are no `Long` or `Double` primitive types.

`String` is not a primitive type; it is a separate built-in immutable text
value documented in `string-values.md`. Eido does not use a `Void` type; a
function with no result simply omits the `returns` clause.

## Primitive literals

```text
true
false

42
2147483648        // still Int

1.5
123456789.125     // Float

'A'
'\n'
'\u0041'
```

Numeric width suffixes such as `42L`, `1.5F`, and `1.5D` are rejected.
The literal syntax does not expose backend width distinctions.

Byte and Short have no invented literal suffix. An integer literal may take an
expected Byte or Short type when the value fits that type:

```text
takeByte(127);    // valid
takeByte(128);    // rejected
```

An unconstrained whole-number literal is Int.

## Functions

Functions accept any number of comma-separated Java-style typed parameters:

```text
function mix(
    Bool flag,
    Byte tiny,
    Short small,
    Int count,
    Float ratio,
    Char marker
) returns Int {
    return count;
}
```

There is no language-level parameter-count cap in the grammar. Parameters and
arguments are stored as sequences and arity is checked exactly.

A function has either zero or one result.

Zero result:

```text
function notify(Int id) {
    return;
}
```

The final bare `return;` is optional, so an empty body is also valid.

One result:

```text
function size() returns Int {
    return 10;
}
```

A one-result function must return a value of its declared primitive type. A
zero-result function may not return a value.

Function calls may be used as statements:

```text
notify(10);
size();
```

When a value-returning function is called as a statement, its result is
explicitly discarded by the backend. A zero-result function cannot be used as
a value expression.

## Current conversion/operator boundary

This does not introduce a general primitive conversion system. Exact primitive
types are required except for contextually typed integer literals used with
Byte or Short.

Arithmetic currently accepts matching Int operands or matching Float operands.
Byte, Short, Char, and Bool arithmetic/promotion rules remain separate work.

Parameter mutation with `set` remains unsupported; mutable local `var` bindings use
the explicit `set` mutation behavior.
