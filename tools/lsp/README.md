# Eido LSP

`eido-lsp` is the editor-neutral language-server adapter over Eido's compiler
tooling APIs. It deliberately contains no independent parser, resolver, type
checker, or module semantics.

Current incremental surface:

- standard Content-Length JSON-RPC transport over stdio;
- initialize/shutdown/exit lifecycle;
- full text-document synchronization;
- live diagnostics on open/change/save/close;
- unsaved editor overlays compiled through the real module/project pipeline;
- project discovery from the root `module.yaml`;
- semantic hover from typed HIR;
- compiler-grounded semantic tokens for classes, interfaces, functions, methods, fields, parameters, and locals;
- go-to-definition across source/module files;
- full-document source formatting through compiler tooling;
- warning when an opened `.eido` file is not listed in its module manifest.

Build it with:

```text
nimble buildLsp
```

The resulting `eido-lsp` binary can be used by VS Code, Neovim, Emacs, Zed,
or any other client that can launch a stdio LSP server.

The permanent policy remains requirement-driven: the thin Nim adapter is
bootstrap infrastructure. As Eido gains the JSON/stdio/collections/project-state
capabilities required to express the server cleanly, ordinary LSP implementation
code should migrate to Eido while compiler semantic/query services remain
protocol-neutral.

Next incremental capabilities should be added when their compiler facts exist:
references, completion/member completion, signature help, rename, and safe code
actions.
