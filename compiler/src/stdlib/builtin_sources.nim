## Embeds the manifest-defined Eido standard-library module tree into the compiler.
## Normal module projects receive its umbrella root through an implicit
## `eido.stdlib` dependency while declarations retain their owning child module.

import std/[os, strutils]
import ../source/source_unit
import ../project/modules/[manifest_parser, model]

const
  BuiltinStdlibModuleName* = "eido.stdlib"
  BuiltinProcessModuleName* = "eido.stdlib.process"
  BuiltinIoModuleName* = "eido.stdlib.io"
  BuiltinMemoryModuleName* = "eido.stdlib.memory"
  BuiltinManagedGcModuleName* = "eido.stdlib.memory.managed"

  BuiltinStdlibManifestPath* = "<eido-sdk>/stdlib/module.yaml"
  BuiltinProcessManifestPath* = "<eido-sdk>/stdlib/process/module.yaml"
  BuiltinIoManifestPath* = "<eido-sdk>/stdlib/io/module.yaml"
  BuiltinMemoryManifestPath* = "<eido-sdk>/stdlib/memory/module.yaml"
  BuiltinManagedGcManifestPath* =
    "<eido-sdk>/stdlib/memory/managed/module.yaml"

  BuiltinStdlibManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/module.yaml"
  )
  BuiltinProcessManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/process/module.yaml"
  )
  BuiltinIoManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/io/module.yaml"
  )
  BuiltinMemoryManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/module.yaml"
  )
  BuiltinManagedGcManifestSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/module.yaml"
  )

  BuiltinProcessSourcePath* = "eido://stdlib/process/process.eido"
  BuiltinConsoleSourcePath* = "eido://stdlib/io/console.eido"
  BuiltinMemorySourcePath* = "eido://stdlib/memory/memory.eido"
  BuiltinArenaSourcePath* = "eido://stdlib/memory/arena.eido"
  BuiltinManagedGcNativeSourcePath* =
    "eido://stdlib/memory/managed/managed_gc_native.eido"
  BuiltinManagedGcRuntimeSourcePath* =
    "eido://stdlib/memory/managed/managed_gc_runtime.eido"

  BuiltinProcessSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/process/process.eido"
  )
  BuiltinConsoleSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/io/console.eido"
  )
  BuiltinMemorySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/memory.eido"
  )
  BuiltinArenaSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/arena.eido"
  )
  BuiltinManagedGcNativeSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/managed_gc_native.eido"
  )
  BuiltinManagedGcRuntimeSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/managed_gc_runtime.eido"
  )

  BuiltinNativeSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_native.nim"
  )
  BuiltinStorageSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_storage.nim"
  )
  BuiltinManagedGcSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_managed_gc.nim"
  )

## Returns one embedded SDK manifest by its stable virtual installation path.
proc embeddedStdlibManifest(manifestPath: string): string =
  case manifestPath
  of BuiltinStdlibManifestPath:
    BuiltinStdlibManifestSource
  of BuiltinProcessManifestPath:
    BuiltinProcessManifestSource
  of BuiltinIoManifestPath:
    BuiltinIoManifestSource
  of BuiltinMemoryManifestPath:
    BuiltinMemoryManifestSource
  of BuiltinManagedGcManifestPath:
    BuiltinManagedGcManifestSource
  else:
    raise newException(
      ValueError,
      "embedded stdlib references unknown manifest '" & manifestPath & "'"
    )

## Resolves one manifest-owned stdlib source to its embedded compiler payload.
## Manifests control module membership; this table only supplies installed bytes.
proc embeddedStdlibSource(
  manifestPath,
  sourceEntry: string
): tuple[path, text: string] =
  let key = manifestPath & "|" & sourceEntry
  case key
  of BuiltinProcessManifestPath & "|process.eido":
    (BuiltinProcessSourcePath, BuiltinProcessSource)
  of BuiltinIoManifestPath & "|console.eido":
    (BuiltinConsoleSourcePath, BuiltinConsoleSource)
  of BuiltinMemoryManifestPath & "|memory.eido":
    (BuiltinMemorySourcePath, BuiltinMemorySource)
  of BuiltinMemoryManifestPath & "|arena.eido":
    (BuiltinArenaSourcePath, BuiltinArenaSource)
  of BuiltinManagedGcManifestPath & "|managed_gc_native.eido":
    (BuiltinManagedGcNativeSourcePath, BuiltinManagedGcNativeSource)
  of BuiltinManagedGcManifestPath & "|managed_gc_runtime.eido":
    (BuiltinManagedGcRuntimeSourcePath, BuiltinManagedGcRuntimeSource)
  else:
    raise newException(
      ValueError,
      "embedded stdlib manifest '" & manifestPath &
        "' references unknown source '" & sourceEntry & "'"
    )

## Recursively materializes one embedded stdlib module from its manifest.
proc loadEmbeddedStdlibModule(
  manifestPath,
  parentCanonical,
  expectedLocalName: string,
  sources: var seq[SourceUnit],
  modules: var seq[ModuleSpec],
  embeddedSourcePaths: var seq[string]
): string =
  let manifest = parseModuleManifest(
    embeddedStdlibManifest(manifestPath),
    manifestPath
  )

  if expectedLocalName.len > 0 and manifest.name != expectedLocalName:
    raise newException(
      ValueError,
      "embedded stdlib child manifest '" & manifestPath &
        "' declares module '" & manifest.name &
        "' but parent declared child '" & expectedLocalName & "'"
    )

  let canonical =
    if parentCanonical.len == 0:
      "eido." & manifest.name
    else:
      parentCanonical & "." & manifest.name

  var spec = ModuleSpec(
    name: manifest.name,
    canonicalName: canonical,
    parentName: parentCanonical,
    manifestPath: manifestPath,
    directory: parentDir(manifestPath),
    dependencies: manifest.dependencies,
    exports: manifest.exports,
    adopts: manifest.adopts
  )

  let ownIndex = modules.len
  modules.add spec

  for sourceEntry in manifest.sources:
    let embedded = embeddedStdlibSource(manifestPath, sourceEntry)
    if embedded.path in embeddedSourcePaths:
      raise newException(
        ValueError,
        "embedded stdlib source is declared more than once: " & embedded.path
      )
    embeddedSourcePaths.add embedded.path
    modules[ownIndex].sourcePaths.add embedded.path
    sources.add initSourceUnit(
      sources.len,
      embedded.path,
      embedded.text,
      canonical
    )

  for child in manifest.children:
    let childManifestPath =
      parentDir(manifestPath) / child.path / "module.yaml"
    let childCanonical = loadEmbeddedStdlibModule(
      childManifestPath,
      canonical,
      child.name,
      sources,
      modules,
      embeddedSourcePaths
    )
    modules[ownIndex].children.add childCanonical

  for provision in manifest.provides:
    modules[ownIndex].provides.add ModuleProvision(
      contract: provision.contract,
      providerModule: provision.by
    )

  canonical

## Adds the recursively manifest-defined SDK stdlib and makes its umbrella root
## an implicit dependency of the user project's root module.
proc addBuiltinStdlib*(
  sources: var seq[SourceUnit],
  modules: var seq[ModuleSpec],
  rootModule: string
) =
  for moduleSpec in modules:
    if moduleSpec.canonicalName == BuiltinStdlibModuleName or
        moduleSpec.canonicalName.startsWith(BuiltinStdlibModuleName & "."):
      raise newException(
        ValueError,
        "module identity '" & moduleSpec.canonicalName &
          "' is reserved by the Eido SDK"
      )

  var embeddedSourcePaths: seq[string]
  let stdlibRoot = loadEmbeddedStdlibModule(
    BuiltinStdlibManifestPath,
    "",
    "stdlib",
    sources,
    modules,
    embeddedSourcePaths
  )
  if stdlibRoot != BuiltinStdlibModuleName:
    raise newException(
      ValueError,
      "embedded stdlib root must resolve to '" & BuiltinStdlibModuleName & "'"
    )

  for index in 0 ..< modules.len:
    if modules[index].canonicalName == rootModule:
      if BuiltinStdlibModuleName notin modules[index].dependencies:
        modules[index].dependencies.add BuiltinStdlibModuleName
      return

  raise newException(
    ValueError,
    "compiler invariant: root module '" & rootModule & "' was not loaded"
  )
