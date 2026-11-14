The standard library is a normal Eido module tree shipped with the SDK. `eido.stdlib` is a source-free umbrella module; independent capabilities own child modules so their dependencies, exports, tests, and documentation can evolve separately.

```text
eido.stdlib
├── process                  Process
├── io                       Console
├── storage                  Storage<T>
├── collections              Array<T>, Arrays<T>
└── memory                   memory-policy namespace
    ├── managed              selectable default tracing GC
    └── rc                   selectable reference-counting policy
```

The umbrella re-exports ordinary public roots from these children. Stateful collection implementations remain internal: `Array<T>` is an exported interface, while `Arrays<T>` is the exported static factory and the backing `StorageArray<T>` class stays module-internal.

`Storage<T>` is ordinary SDK Eido layered over compiler/backend raw `Storage<Byte>` and private representation bridges. It is the physical dynamic-memory substrate used by collections, language runtimes, and memory-policy runtimes. `memory.managed` is the SDK default policy selected by `--memory=gc`; `memory.rc` is an optional deferred/recounting reference-counting policy. Custom project modules declaring `policySources` use the same compiler path.

Backend-specific implementation support lives under `stdlib/native/`. The Nim backend supplies irreducible host/machine support there; ordinary Eido source modules never name Nim modules or symbols.

## SDK integration

Every stdlib module has its own `module.yaml`. The bootstrap compiler embeds the root and child manifests plus their source payloads, recursively materializes the same module tree an installed SDK exposes, and adds only `eido.stdlib` as the implicit application dependency. Child ownership and visibility therefore use ordinary Eido module semantics instead of a compiler-only flattened namespace.

## API reference

Public SDK declarations use `///` documentation comments. Generate the authoritative reference directly from the embedded SDK module tree:

```text
eido doc --stdlib
```

The generated HTML separates public API, module-internal Eido declarations, and compiler-private/backend support. The accompanying `api.json` exposes the same model for tooling.
