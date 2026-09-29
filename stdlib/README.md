# Eido standard library

The standard library contains foundational APIs guaranteed to ship with the Eido SDK. It is library functionality, not additional language syntax.

Current first Eido-facing APIs live under `stdlib/src/` as direct class-owned native methods:

- `Process.argumentCount()`, `Process.argument(index)`, and `Process.exit(code)`.
- `Console.writeLine(value)` and `Console.errorLine(value)`.

These classes require no utility instances, no `static` keyword, and no Eido wrapper functions. Their bodyless `native function` members are type-associated/static by definition in v0 and bind directly to backend support.

Backend-specific implementation support lives under `stdlib/native/`. The Nim backend currently supplies `stdlib/native/nim/eido_native.nim`; Eido source never names Nim modules or symbols.

## SDK/project integration

Normal module projects receive this foundational stdlib implicitly through the compiler-owned `eido.stdlib` module. User `module.yaml` files therefore do not list repository-relative paths to `process.eido` or `console.eido`. The source declarations are embedded into the installed bootstrap compiler so source-installed Eido projects remain portable outside the Eido repository.

The current Nim backend support source is embedded as an installation fallback as well. `EIDO_NATIVE_NIM_PATH` remains available as an explicit development/SDK override. Standalone `eido compile` remains a lower-level source compilation route; normal applications should use `module.yaml` projects for the SDK stdlib and architecture model.
