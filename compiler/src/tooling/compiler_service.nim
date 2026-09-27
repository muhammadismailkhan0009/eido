## Exposes protocol-neutral compiler operations for CLI, MCP, LSP, and other tooling adapters.
## Example: an adapter can compile Eido source to backend source without importing parser or semantic internals.

import ../pipeline/compiler

## Compiles one complete Eido source program through the pure compiler pipeline to Nim source.
## Example: compileSourceToNim("function main() returns Int { return 1; }") returns generated Nim.
proc compileSourceToNim*(source: string): string =
  compileToNim(source)
