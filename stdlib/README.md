# Eido standard library

The standard library is a normal Eido module tree shipped with the SDK. `eido.stdlib` is a source-free umbrella module; independent capabilities own child modules so their dependencies, exports, tests, and documentation can evolve separately.

```text
eido.stdlib
├── process                  Process
├── io                       Console
└── memory                   Memory, Arena
    └── managed              compiler-private GC runtime
```

The umbrella re-exports the ordinary public roots, so applications continue to use `Process`, `Console`, `Memory`, and transitively `Arena` without declaring additional dependencies. The `memory.managed` child is intentionally not exported.

`Storage<T>` remains a compiler-provided foundational type rather than an Eido source declaration. It belongs conceptually to the memory subsystem and is the physical substrate used by Arena and the managed runtime.

Backend-specific implementation support lives under `stdlib/native/`. The Nim backend supplies host/native implementations there; Eido source modules never name Nim modules or symbols.

## SDK integration

Every stdlib module has its own `module.yaml`. The bootstrap compiler embeds the root and child manifests plus their source payloads, recursively materializes the same module tree an installed SDK exposes, and adds only `eido.stdlib` as the implicit application dependency. Child ownership and visibility therefore use ordinary Eido module semantics instead of a compiler-only flattened namespace.


## API reference

Public SDK declarations use `///` documentation comments. Generate the authoritative reference directly from the embedded SDK module tree:

```text
eido doc --stdlib
```

The generated HTML separates public API, module-internal Eido declarations, and compiler-provided API such as `Storage<T>`. Backend/Nim support is implementation-only and is not presented as Eido API. The accompanying `api.json` exposes the same model for tooling.
