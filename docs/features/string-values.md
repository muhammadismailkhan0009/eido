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

Eido String remains an immutable value with no source-visible object identity, but its target backing is now Eido-owned. The Nim backend represents one String value as an opaque `int64` handle. Hidden ordinary Eido language-runtime code in `stdlib/text/string_runtime.eido` owns the immutable UTF-8 byte allocation through `Storage<Byte>`.

Each current String allocation contains a small runtime header (`next`, byte length) followed by UTF-8 bytes. Literals lower to fixed byte arrays that are copied directly into this Storage-backed representation; `+` and content equality call ordinary hidden Eido runtime methods rather than Nim `&` or Nim string equality.

The current String lifetime policy is deliberately simple: allocations are linked by `StringRuntime` and remain valid for program lifetime, then `stringShutdown()` reconstructs and releases every owning `Storage<Byte>` allocation. Replacing a local or field therefore never invalidates another String handle, and class copy may safely copy the handle because the text itself is immutable.

Native/platform text is an ABI boundary only. A foreign Nim `string` result such as `Process.argument()` is copied immediately into Eido String storage before Eido code observes it. Conversely, `Console.writeLine` and similar native calls materialize a temporary native string from Eido bytes only for the duration of the foreign call. The foreign representation is never the owner of an Eido String value.

A targeted backend regression compiles String allocation, concatenation, equality, and shutdown with Nim `--mm:none`, demonstrating that normal pure String computation no longer depends on Nim's memory manager. Future String policies may add interning, reference counting, or more selective reclamation without changing source semantics.
