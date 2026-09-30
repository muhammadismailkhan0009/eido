# Eido

**Eido** is an experimental compiled programming language for predictable, explicit, enterprise-oriented software.

The project explores a language where architectural boundaries, object semantics, contracts, module visibility, and compiler-grounded tooling are language/toolchain concerns rather than conventions layered on top of libraries.

> **Status:** pre-alpha (`0.0.1`). Eido is ready for experimentation and language development, not production use. Syntax and semantics may still change before v0 is frozen.

## Why Eido?

Eido is being designed around a few deliberate goals:

- **Explicit, low-surprise semantics** inspired by disciplined enterprise languages.
- **Native compilation** with a small runtime footprint; the current backend lowers to Nim and then a native executable.
- **Design by Contract in the language** through `require`, `ensure`, and class `invariant`.
- **Architectural modules and interfaces** with compiler-enforced visibility and behavioral boundaries.
- **LLM- and tooling-friendly semantics**: the compiler owns parsing, name resolution, types, contracts, symbols, and diagnostics; editor/agent tooling consumes those facts rather than reimplementing them.
- **Strong defaults without lock-in**: the `eido` CLI is the official project workflow, while compiler/project APIs remain separable so richer Maven/Gradle/Bazel-style tooling can exist later.

## Install from source

Eido currently ships as a source-installable toolchain. Binary releases/installers are planned later.

### Requirements

- Nim **2.2+** with Nimble.
- A native C toolchain usable by Nim (for example GCC or Clang).
- Git.

### Install

```bash
git clone https://github.com/muhammadismailkhan0009/eido.git
cd eido
nimble install -y
```

Verify the installation:

```bash
eido --version
eido --help
```

If `eido` is not found, make sure Nimble's binary directory is on `PATH`:

```bash
export PATH="$HOME/.nimble/bin:$PATH"
```

The installed compiler embeds the foundational Eido standard library declarations and the Nim backend's native-support source. Normal projects therefore do **not** need paths back into the cloned Eido repository.

## Quick start

Create a project anywhere on disk:

```text
hello-eido/
├── module.yaml
└── Main.eido
```

`module.yaml`:

```yaml
module: hello
sources:
  - Main.eido
children: []
dependencies: []
exports: []
provides: {}
adopts: []
```

`Main.eido`:

```eido
function main() {
    Console.writeLine("Hello, " + Process.argument(0));
}
```

Run it:

```bash
cd hello-eido
eido check
eido run -- Eido
```

Output:

```text
Hello, Eido
```

Build without running:

```bash
eido build
```

The default artifacts are kept under the project root:

```text
build/
├── bin/hello
└── generated/nim/hello_generated.nim
```

Clean generated artifacts with:

```bash
eido clean
```

`eido` discovers the owning outermost `module.yaml`, so these project commands can also be invoked from a nested child-module directory.

## CLI

```text
eido check [module.yaml]
eido build [module.yaml] [-o <output>]
eido run [module.yaml] [-- <application args...>]
eido clean [module.yaml]
eido compile <source.eido>... -o <output>
eido --help
eido --version
```

`check`, `build`, `run`, and `clean` are the normal project workflow. Supplying an explicit `module.yaml` is useful for CI or external orchestration.

`compile` is the lower-level standalone source path. Normal application development should currently prefer a `module.yaml` project because project compilation also provides the implicit SDK standard library and module architecture.

## Language features implemented today

### Core language

- Primitive types: `Bool`, `Byte`, `Short`, `Int`, `Float`, `Char`, and `String`.
- Typed functions with zero or one result.
- Local variables and explicit `set` mutation.
- Arithmetic, comparison, Boolean operators, grouping, and unary negation.
- `if` / `else if` / `else`.
- `while` and C-style `for` loops.
- `break`, `continue`, and `return`.
- Optional values with explicit presence handling.

### Classes and object semantics

- Nominal classes with fields and methods.
- Named-field construction.
- Explicit `self` receiver semantics.
- Static/type-associated methods inferred when `self` is not required; no `static` keyword.
- Generic classes with compiler specialization.
- Compiler-owned unified `Storage<T>` memory substrate: `Storage<Byte>.allocateRaw` is the single physical owned-allocation path; typed allocation adopts that raw backing, typed `view`/`slice` capabilities are allocation-free, `size`/`alignment` expose target layout through Storage itself, and ownership/release is compiler/runtime enforced. Higher allocation strategies, objects, and collections are intended to build above this same substrate.
- Explicit class graph `copy` / `ref` semantics and detached class-valued returns.
- No class inheritance.

### Interfaces

- Nominal interfaces and explicit `implements`.
- Single-interface `extends` in v0.
- Runtime interface dispatch and class-to-interface conversion.
- Multiple implemented interfaces when their required method identities are non-conflicting.
- Behavioral interface contracts that propagate into implementations.
- Child-interface method redeclarations may add contracts while preserving the inherited signature and parent obligations.

### Design by Contract

Eido supports contracts as compiler-owned semantic data rather than annotations or library calls:

```eido
class Account {
    Int balance;

    invariant {
        self.balance >= 0;
    }

    function debit(Int amount) returns Int {
        require {
            amount > 0;
            amount <= self.balance;
        }

        set self.balance = self.balance - amount;
        return self.balance;

        ensure {
            result >= 0;
            result == self.balance;
        }
    }
}
```

Implemented contract semantics include:

- `require` for legal invocation state.
- `ensure` for the complete observable successful post-state, including zero-result methods.
- Contextual `result` inside value-returning `ensure` blocks.
- Continuously enforced class invariants: construction, method entry/normal exit, and immediately after `set self.field = ...`.
- Compiler-inferred contract safety for calls used inside contracts; no source-level `pure` keyword.
- Interface `require`/`ensure` propagation into concrete implementations with separate provenance from implementation-declared contracts.

General proof optimization and full static contract implication reasoning are intentionally not implemented yet.

### Modules and project architecture

Normal Eido projects use `module.yaml` as an explicit architecture layer. The current model supports:

- parent/child modules;
- explicit dependencies;
- exported API roots;
- adopted child APIs;
- parent-owned interface providers;
- transitive public API closure;
- canonical module-owned declaration identities;
- qualified names when visible declarations are ambiguous;
- closed interface implementation within the owning module family.

A normal module source file may contain at most one outermost class or interface; top-level functions may coexist with that nominal declaration.

See [`docs/features/modules.md`](docs/features/modules.md) for the detailed model.

### Native boundary and current standard library

Eido supports bodyless native functions/methods as the boundary to backend/platform code.

The initial implicit standard library currently contains:

```text
Process.argumentCount()
Process.argument(index)
Process.exit(code)
Console.writeLine(value)
Console.errorLine(value)
```

The public Eido source does not reference Nim symbols. Backend-specific support remains an implementation detail of the current Nim backend.

## Enterprise demo

[`examples/enterprise_demo`](examples/enterprise_demo) is the best current end-to-end example. It demonstrates:

- a multi-module application;
- exported interfaces and a static application facade;
- internal implementations;
- interface contract inheritance;
- `require`, `ensure`, `invariant`, and contextual `result`;
- runtime interface dispatch;
- deliberate contract failures.

After installing Eido:

```bash
cd examples/enterprise_demo
eido check
eido run -- approve "Acme GmbH"
eido run -- reject "Acme GmbH"
```

The example README documents the deliberate failure scenarios as well.

## Editor/tooling support

The compiler already exposes protocol-neutral tooling used by the Eido language server:

- compiler diagnostics, including unsaved-buffer checking;
- semantic hover;
- semantic tokens;
- Go to Definition across project files;
- compiler-owned formatting.

Build the language server from a clone with:

```bash
nimble buildLsp
```

The development VS Code/Cursor extension is under [`tools/vscode`](tools/vscode). It is not yet published as a marketplace extension; see its README for local development/install instructions.

## What is not implemented yet

The most important current gaps before the v0 language surface is frozen include:

- static interface-contract compatibility reasoning;
- source-level contract failure diagnostics without generated Nim stack frames;
- a finalized constructor/initialization model;
- collections and `for-each` iteration;
- enums and constants;
- a larger String/collection standard library;
- finalized class/interface equality semantics;
- source-level error handling;
- an Eido testing model and `eido test`;
- package/dependency registry and binary SDK releases.

Advanced proof optimization, cross-object invariants, atomic multi-field invariant transitions, generic functions/methods, class inheritance, and a full exception model are intentionally outside the current implemented surface.

## Build Eido from source

From the repository root:

```bash
nimble build -y
nimble test -y
nimble buildLsp -y
```

Useful locations:

```text
compiler/           compiler, semantic analysis, HIR, backend, tooling APIs
stdlib/             foundational Eido APIs and backend-native support
packages/           future higher-level ordinary Eido libraries
tools/cli/          eido CLI
tools/lsp/          language server
tools/vscode/       VS Code/Cursor development extension
tests/integration/  cross-component integration tests
docs/features/      implemented feature documentation
examples/           runnable Eido programs
```

The compiler currently uses Nim as its bootstrap implementation and native backend. The project is progressively dogfooding Eido where the language surface is sufficient.

## Design and implementation notes

- The official `eido` CLI is a default project/build tool, **not** a compiler architecture dependency. Future build systems can orchestrate the compiler/project model independently.
- LSP/editor integrations do not own Eido parsing or type semantics; the compiler remains authoritative.
- Contract runtime checks are currently always enabled. Static verification may later prove checks true/false and eliminate or reject them without changing the source contract model.
- Backend-generated Nim is an implementation artifact, not part of the Eido language specification.

For detailed implemented semantics, start with [`docs/features`](docs/features) and the current v0 specification material under [`docs/specification`](docs/specification).

## Contributing

Contributions and experiments are welcome while Eido is still pre-alpha. Read [`CONTRIBUTING.md`](CONTRIBUTING.md) before changing language semantics or compiler architecture.

## License

Eido is licensed under the MIT License. See [`LICENSE`](LICENSE).
