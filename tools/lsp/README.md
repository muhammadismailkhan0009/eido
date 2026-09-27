# Eido LSP adapter

This area is reserved for the language-server adapter over the compiler tooling/project API. LSP code must not reimplement Eido parsing, name resolution, typing, or member lookup.

The planned incremental surface is diagnostics first, then hover/definition/references, semantic tokens, completion/signature help, rename, and compiler-safe code actions as the underlying compiler services become available.
