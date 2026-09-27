# Eido

Eido is an experimental compiled language focused on predictable enterprise software, explicit semantics, and compiler-grounded verification/tooling.

## Repository layout

- `compiler/` — Eido compiler implementation and compiler/language conformance tests.
- `stdlib/` — foundational APIs shipped with the Eido SDK.
- `packages/` — higher-level ordinary Eido libraries.
- `tools/cli/` — the human-facing `eido` command; Nim bootstrap adapter plus the permanent CLI implementation being written in Eido itself.
- `tools/mcp/` — planned MCP adapter over the protocol-neutral compiler tooling API.
- `tools/lsp/` — planned language-server adapter over the same compiler tooling/project API.
- `installer/` — SDK installation/assembly ownership.
- `tests/integration/` — cross-component integration tests.
- `docs/` — architecture, feature, testing, and v0 specification documentation.
- `examples/` — Eido example programs.

Run `nimble build` to build the CLI and `nimble test` to run compiler, language, and toolchain integration tests.

Current explicit multi-source commands:

```text
eido build src/main.eido src/account.eido src/service.eido -o app
eido check src/main.eido src/account.eido src/service.eido
```

`eido check` performs project parsing + semantic analysis only; it does not invoke the Nim emitter/toolchain. Compiler errors are emitted as structured diagnostics rendered like `path:line:column error EIDO1000: message`.

All supplied files currently form one project declaration universe; module/import/package boundaries are intentionally not implemented yet.

## Requirement-driven dogfooding

Eido's ecosystem is now grown through permanent product requirements rather than throwaway examples. The first Eido-written product is `tools/cli/eido/main.eido`; it already implements help/version/error/exit behavior using direct class-owned native stdlib APIs such as `Console.writeLine(...)` and `Process.argument(...)`. No Eido `platform*` wrapper layer sits between those public APIs and backend native support. The Nim compiler remains the bootstrap compiler/core, while ordinary tooling migrates to Eido as the language gains the required capabilities.
