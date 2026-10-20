# Generated API documentation

Eido generates API reference material from the compiler's real module visibility model rather than maintaining a separate handwritten list of public declarations.

## Commands

Document the current module project:

```text
eido doc
eido doc module.yaml
eido doc module.yaml -o site/api
```

The default project output is:

```text
build/docs/
├── index.html
└── api.json
```

Document the SDK standard library directly from the compiler-embedded manifests and sources:

```text
eido doc --stdlib
eido doc --stdlib -o site/stdlib
```

The default SDK-only output is `build/docs/stdlib` in the current directory.

## Documentation comments

A contiguous `///` block immediately above a declaration is its API documentation:

```eido
/// Process-wide operations supplied by the active backend.
class Process {
    /// Returns the number of command-line arguments.
    native function argumentCount() returns Int;
}
```

Ordinary `//` remains an implementation comment. A blank line or ordinary comment breaks attachment.

Documentation comments remain lexer trivia. They do not enter the AST/HIR and therefore do not change compilation semantics.

## Visibility

The generator does not infer publicness from comments.

It reuses Eido's module architecture rules:

- explicit manifest exports are public roots;
- the compiler computes transitive nominal API closure through fields, callable signatures, implemented/extended interfaces, and nested generic arguments;
- a declaration reachable through that closure is shown as **Public API**;
- declarations outside all public surfaces are shown as **Module-internal**;
- top-level functions remain module-internal because Eido does not export them.

Each public declaration records the modules from which it is visible, so re-exports and transitive exposure are explicit.

Members of a reachable concrete class are documented according to the ordinary class rules. This intentionally exposes architectural consequences. For example, if a class becomes public through an exported signature, its readable/constructible fields are part of the current public surface even when the class was not an explicit export root.

## SDK and compiler-private capabilities

Public SDK APIs declared in `.eido` source are documented through the same module/public-surface model as application code. For example, `Storage<T>` is owned by `eido.stdlib.storage` and appears as an ordinary SDK source declaration.

Compiler-private representation bridges and backend support symbols are not promoted into the public reference. Raw `Storage<Byte>` operations that are compiler-backed remain implementation capabilities attached to that SDK abstraction rather than a separate compiler-owned public type.

## What is not API

Backend support and compiler implementation symbols are not promoted into API documentation merely because they exist in the repository.

Examples include:

- generated Nim identifiers;
- native-provider procedure names;
- GC bridge implementation procedures;
- compiler helper procedures and internal data structures.

Hidden Eido runtime declarations such as the managed GC runtime remain visible only under the **Module-internal** section because they are real Eido source declarations but are not exported.

## Output formats

`index.html` is a self-contained browsable reference with module navigation, signatures, documentation comments, visibility badges, source ownership, and member lists.

`api.json` contains the same documentation model for future LSP, MCP, website, package-index, or agent tooling. Protocol adapters should consume this model rather than reimplement visibility analysis.
