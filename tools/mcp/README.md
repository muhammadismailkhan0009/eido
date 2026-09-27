# Eido MCP adapter

This area is reserved for the MCP transport over the compiler tooling API. MCP protocol logic must not become part of compiler semantics.

The compiler now provides the first useful MCP-facing project capability: semantic-only project checking with source-aware structured diagnostics through `checkProject` / `ProjectCheckResult`. The MCP transport/tools themselves are not implemented yet.

The planned installed entry point is `eido mcp`.
