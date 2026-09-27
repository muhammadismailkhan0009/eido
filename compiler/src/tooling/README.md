# Compiler tooling API

This area owns protocol-neutral, structured compiler capabilities used by CLI, MCP, LSP, CI, and future agent integrations.

Adapters must depend on this tooling boundary rather than reaching into parser or semantic-analysis internals when a stable tooling operation exists.
