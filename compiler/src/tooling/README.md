# Compiler tooling API

This area owns protocol-neutral, structured compiler capabilities used by CLI, MCP, LSP, CI, and future agent integrations.

Current permanent services include project checking/compilation, typed-HIR hover, canonical formatting, lexical comment ranges, and semantic symbol indexing for declaration/reference identity, semantic highlighting, and navigation. `comment_service.nim` exposes `//` ranges from lexer-trivia gaps without promoting comments into AST/HIR. The symbol service is split under `tooling/symbols/` by source-token matching, definition registries, expression/statement traversal, index construction, and queries.

Adapters must depend on this tooling boundary rather than reaching into parser or semantic-analysis internals when a stable tooling operation exists.
