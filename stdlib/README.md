# Eido standard library

The standard library contains foundational APIs guaranteed to ship with the Eido SDK. It is library functionality, not additional language syntax.

Current foundational Eido-facing APIs live under `stdlib/src/`:

- `Process.argumentCount()`, `Process.argument(index)`, and `Process.exit(code)`.
- `Console.writeLine(value)` and `Console.errorLine(value)`.
- `Arena<T>`, the first memory-management policy implemented entirely in Eido above `Storage<T>`.
- `Memory<T>`, a stateless stdlib export root that exposes the stateful Arena API transitively without weakening normal module export rules.

`Process` and `Console` require no utility instances, no `static` keyword, and no Eido wrapper functions. Their bodyless `native function` members are type-associated/static by definition in v0 and bind directly to backend support.

`Arena<T>` is ordinary Eido code, not a native wrapper. It owns one `Storage<T>`, advances a sequential allocation cursor, returns borrowed Storage slices, supports bulk reset, and delegates all physical allocation/alignment/address mechanics to Storage.

Backend-specific implementation support lives under `stdlib/native/`. The Nim backend currently supplies `stdlib/native/nim/eido_native.nim` for host APIs and `stdlib/native/nim/eido_storage.nim` for the physical Storage substrate; Eido source never names Nim modules or symbols.

## SDK/project integration

Normal module projects receive this foundational stdlib implicitly as `eido.stdlib`. The stdlib's own architecture is declared by the real `stdlib/module.yaml`; that manifest owns the Eido source list and public export roots just like an ordinary module manifest. The bootstrap compiler embeds both the manifest and its declared source payloads, then parses the manifest through the normal module-manifest parser so installed compilers remain repository-independent without maintaining a second handwritten stdlib module definition. User `module.yaml` files therefore do not list repository-relative paths to `process.eido`, `console.eido`, `arena.eido`, or `memory.eido`.

The current Nim backend support source is embedded as an installation fallback as well. `EIDO_NATIVE_NIM_PATH` remains available as an explicit development/SDK override. Standalone `eido compile` remains a lower-level source compilation route; normal applications should use `module.yaml` projects for the SDK stdlib and architecture model.
