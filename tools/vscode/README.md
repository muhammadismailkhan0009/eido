# Eido VS Code support

This extension is a thin client for the editor-neutral `eido-lsp` server.

Current functionality:

- `.eido` language registration and syntax coloring;
- live compiler diagnostics for unsaved buffers;
- semantic hover from typed HIR;
- semantic highlighting from compiler symbol facts;
- **Go to Definition** / Ctrl+click across Eido source files;
- compiler-owned **Format Document** support;
- **Eido: Check Project**;
- **Eido: Build Project**;
- **Eido: Build and Run Project**.

The extension does not implement parsing, type checking, module resolution, or
completion logic. Those capabilities belong to compiler tooling / the LSP.

## Development setup

From the Eido repository:

1. Build the compiler with `nimble build`.
2. Build the language server with `nimble buildLsp`.
3. Ensure `eido` and `eido-lsp` are on PATH, or configure
   `eido.compiler.path` and `eido.server.path`.
4. Run `npm install` in `tools/vscode`.
5. Launch the extension from VS Code's Extension Development Host, or package/install the VSIX into Cursor/VS Code.

For local Cursor development, `cursor --install-extension <path-to-vsix> --force` installs the packaged extension. When `eido.server.path` / `eido.compiler.path` are empty, the extension walks upward from the workspace root to find workspace-local `eido-lsp` / `eido` binaries before falling back to PATH.

The workspace root should contain the root `module.yaml`.
