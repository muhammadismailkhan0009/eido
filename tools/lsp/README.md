# Eido LSP adapter

This area is reserved for the language-server adapter over the compiler tooling/project API. LSP code must not reimplement Eido parsing, name resolution, typing, or member lookup.

The compiler now provides the first required LSP foundation: source-aware structured diagnostics through `checkProject` / `ProjectCheckResult`. The LSP transport itself is not implemented yet.

Under the requirement-driven development model, the intended permanent language server should be written in Eido once protocol/stdio/JSON/collections/project-state requirements can be expressed cleanly. Do not grow an independent semantic implementation in Nim.

The planned incremental surface is diagnostics first, then hover/definition/references, semantic tokens, completion/signature help, rename, and compiler-safe code actions as the underlying compiler services become available.
