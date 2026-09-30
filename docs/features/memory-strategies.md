# Memory strategies

Eido memory management is selected as compilation policy rather than being hard-wired into one compile-time program.

The current compiler accepts:

```text
eido build --memory=gc
eido build --memory=manual
eido run --memory=gc
eido compile Main.eido --memory=manual -o app
```

`gc` is the default.

## Strategy boundary

The compiler owns a generic build-machine runner. The runner contains no memory-layout or tracing policy:

```eido
function main() {
    SelectedMemoryStrategy.plan();
}
```

The selected strategy module supplies the private static `SelectedMemoryStrategy.plan()` contract. The current `gc` implementation is a precise mark-and-sweep planner written in Eido. It computes class field offsets, payload size/alignment, and which fields contain managed references.

The compiler supplies semantic facts through private invocation-local handles (`Compiler`, `TypeInfo`, `FieldInfo`) and dynamic Storage layout through the private `StorageInfo` adapter. Strategy code records decisions through `MemoryPlan`. None of these contracts are visible to ordinary Eido programs or emitted into target binaries.

Adding another built-in automatic strategy therefore means supplying another strategy implementation behind the same runner contract and registering its compiler selection. A public third-party strategy package format is deliberately deferred until the internal contract has been exercised by more than one automatic strategy.

## Manual mode

`--memory=manual` performs no managed-memory planning. Until Eido has an explicit manual representation/lifetime model for ordinary class objects, the compiler conservatively rejects ordinary managed class declarations in manual mode.

Primitive and compiler-owned `Storage<T>` programs can already use manual mode. The Nim backend memory-manager option (`--mm:none` in backend tests) is separate from Eido's `--memory=manual`; Eido strategy selection must not be conflated with the implementation language's memory manager.

## Current implementation boundary

The compile-time strategy result is already computed and validated, but the backend does not yet consume that plan to generate the mark-and-sweep runtime. Class values still use the current Nim backend representation.

The next memory-management work is therefore to make the selected `CompileTimeMemoryPlan` a backend input, then extend the strategy contract with function/local/parameter root planning before implementing the runtime collector over Storage.
