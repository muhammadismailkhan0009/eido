# Eido standard library

The standard library contains foundational APIs guaranteed to ship with the Eido SDK. It is library functionality, not additional language syntax.

Current first Eido-facing APIs live under `stdlib/src/` and dogfood inferred static class methods:

- `Process.argumentCount()`, `Process.argument(index)`, and `Process.exit(code)`.
- `Console.writeLine(value)` and `Console.errorLine(value)`.

`Process` and `Console` require no utility instances and no `static` keyword: their self-free class functions are inferred static by the language.

Backend-specific implementation support lives under `stdlib/native/`. The Nim backend currently supplies `stdlib/native/nim/eido_native.nim`; ordinary Eido code reaches it only through explicit `native function` declarations.
