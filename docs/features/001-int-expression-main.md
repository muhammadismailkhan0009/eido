# Feature 001 — Integer expression program

Status: approved and implemented first.

The accepted source form is:

```text
function main() returns Int {
    return 10 + 20 * 3;
}
```

This feature includes integer literals, `+`, `-`, `*`, `/`,
parenthesized expressions, a zero-argument function declaration,
`returns Int`, `return`, braces, and semicolon statement termination.

A closing brace terminates its block. Function and other block declarations
are not followed by a comma, semicolon, or other terminator.

The compiler preserves arithmetic precedence, type-checks the program as
`Int`, emits Nim source, and invokes Nim to produce a native executable.

For Feature 001 only, generated Nim prints the value returned by Eido
`main`. This is a compiler-development harness, not an Eido I/O feature.

No variables, calls, classes, interfaces, modules, or user-visible I/O
belong to this feature.
