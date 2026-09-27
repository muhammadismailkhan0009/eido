# Built-in String values

Status: approved and implemented.

Eido provides `String` as a built-in immutable text value. It is deliberately
not one of the fixed-size scalar primitive types and is not a nominal class.

The semantic type model therefore distinguishes:

```text
primitive  -> Bool Byte Short Int Float Char
String     -> built-in immutable text value
class      -> nominal class identity
```

A String has no source-level object identity. `copy` and `ref` remain
class-only operations and are rejected for String values.

## Literals and flow

String literals use double quotes:

```eido
var name = "Alice";
var empty = "";
```
The initial escape set is:

```text
\\n  newline
\\r  carriage return
\\t  tab
\\\\  backslash
\\"  double quote
```

Direct UTF-8 text in source literals is preserved. String indexing, Unicode
scalar/code-unit indexing rules, normalization, and interpolation are not yet
part of this slice.

String may appear in function/method parameters and results and in class fields:

```eido
function greet(String name) returns String {
    return "Hello " + name;
}

class User {
    String name;
}
```

Ordinary meaningful value flow is allowed through calls, returns, construction
fields, and field access.
## Binding and mutation rules

The existing local-binding discipline remains unchanged. Merely creating a
second local name for an existing binding is invalid:

```eido
var first = "Eido";
var second = first; // invalid
```

Use the existing binding when no new computation or boundary requires another
value. This rule is independent of String's backend storage strategy.

A String's contents are immutable, but a mutable Eido storage location may be
replaced with another String value:

```eido
var name = "Alice";
set name = "Bob";
```

Class-owned behavior may similarly replace an own String field:

```eido
function rename(String value) {
    set self.name = value;
}
```
No operation currently mutates the contents of an existing String value.

## Operators

String supports concatenation with `+`:

```eido
return "Hello " + name;
```

String supports content equality with `==` and `!=`. Ordered comparisons are
not supported.

Subtraction, multiplication, division, numeric negation, Boolean operators, and
class equality semantics do not apply to String.

## Backend and memory boundary

The current Nim backend lowers Eido String to Nim `string` and lowers String
`+` to Nim `&`. Nim currently owns the physical storage, allocation, lifetime,
and reclamation of those values.

That representation is not an Eido language commitment. Eido specifies an
immutable text value with no observable storage identity; a future backend may
share buffers, copy them, intern literals, reference-count them, or use another
representation without changing source semantics.
