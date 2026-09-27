# Eido

Eido is an experimental compiled language focused on predictable enterprise software, explicit semantics, and compiler-grounded verification/tooling.

## Repository layout

- `compiler/` — Eido compiler implementation and compiler/language conformance tests.
- `stdlib/` — foundational APIs shipped with the Eido SDK.
- `packages/` — higher-level ordinary Eido libraries.
- `tools/cli/` — the human-facing `eido` command adapter.
- `tools/mcp/` — planned MCP adapter over the protocol-neutral compiler tooling API.
- `tools/lsp/` — planned language-server adapter over the same compiler tooling/project API.
- `installer/` — SDK installation/assembly ownership.
- `tests/integration/` — cross-component integration tests.
- `docs/` — architecture, feature, testing, and v0 specification documentation.
- `examples/` — Eido example programs.

Run `nimble build` to build the CLI and `nimble test` to run compiler, language, and toolchain integration tests.

Current explicit multi-source build form:

```text
eido build src/main.eido src/account.eido src/service.eido -o app
```

All supplied files currently form one project declaration universe; module/import/package boundaries are intentionally not implemented yet.
