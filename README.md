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

Run `nimble build` to build the bootstrap CLI and `nimble test` to run compiler, language, and cross-component integration tests.

## Project workflow

A normal Eido application is rooted at its architecture `module.yaml`. The official `eido` tool discovers the outermost project manifest from the current directory, so ordinary development does not require repeating the manifest path:

```text
eido check
eido build
eido run -- <application arguments...>
eido clean
```

Default native artifacts are isolated below the project root:

```text
build/
├── bin/<root-module-name>
└── generated/nim/<root-module-name>_generated.nim
```

These paths are defaults of the official project tool, not compiler requirements. Explicit orchestration remains supported:

```text
eido check path/to/module.yaml
eido build path/to/module.yaml -o custom/output
eido run path/to/module.yaml -- <application arguments...>
```

The lower-level standalone compiler route remains separate from the module project workflow:

```text
eido compile Main.eido Helper.eido -o app
```

This separation is intentional: the compiler/project APIs do not depend on the CLI layout, so future Maven/Gradle/Bazel-style tooling may supply its own build graph, artifact directories, caching, profiles, or lifecycle while reusing Eido's compiler and module model. `eido test` is deliberately not exposed yet because Eido's testing model has not been designed; the project tool will own that lifecycle command once the language/runtime has a real test model.

## Requirement-driven dogfooding

Eido's ecosystem is now grown through permanent product requirements rather than throwaway examples. The first Eido-written product is `tools/cli/eido/main.eido`; it already implements help/version/error/exit behavior using direct class-owned native stdlib APIs such as `Console.writeLine(...)` and `Process.argument(...)`. No Eido `platform*` wrapper layer sits between those public APIs and backend native support. The Nim compiler remains the bootstrap compiler/core, while ordinary tooling migrates to Eido as the language gains the required capabilities.
