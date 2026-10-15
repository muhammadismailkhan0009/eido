# Dependency resolution package

Permanent Eido package for resolving package-version requirements before the compiler receives a final module graph.

## Structure

```text
dependency-resolution/
├── module.yaml
├── Version.eido
├── PackageCatalog.eido
├── ResolutionResult.eido
├── DependencyResolver.eido
└── tests/
    ├── module.yaml
    ├── VersionTests.eido
    ├── ResolverTests.eido
    └── Main.eido
```

Production code is owned directly by `dependency_resolution`. Tests are package-owned but use their own executable module root, so testing code is not part of the production module.

## Current capability

The resolver supports semantic `major.minor.patch` versions, multiple releases per package, minimum-version requirements, highest-compatible selection, shared-dependency deduplication, and failure when no release satisfies a requirement.

`Storage<Class>` is not yet part of Eido's public Storage surface, so internal package data currently uses parallel `Storage<String>` and `Storage<Int>` tables rather than introducing a language feature just for this package.

## Tests

The tests use the reusable `packages/testing` assertion package. Run them from the repository root with:

```bash
eido test packages/dependency-resolution
eido test packages/dependency-resolution --memory=eido.stdlib.memory.rc
```

The root integration suite also executes this same Eido-owned test suite under both policies to verify compiler/runtime integration.

## Next resolver work

The next meaningful capability is richer version constraints, especially upper bounds/ranges. Registry access, lockfiles, filesystem access, and networking remain outside the resolver core.
