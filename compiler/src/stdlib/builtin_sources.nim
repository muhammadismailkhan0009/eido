## Embeds the manifest-defined Eido standard-library module tree into the compiler.
## Normal module projects receive its umbrella root through an implicit
## `eido.stdlib` dependency while declarations retain their owning child module.

import std/[os, strutils]
import ../source/source_unit
import ../project/model as projectModel
import ../project/modules/[manifest_parser, model]
import embedded_catalog

const
  BuiltinStdlibModuleName* = "eido.stdlib"
  BuiltinProcessModuleName* = "eido.stdlib.process"
  BuiltinIoModuleName* = "eido.stdlib.io"
  BuiltinStorageModuleName* = "eido.stdlib.storage"
  BuiltinCollectionsModuleName* = "eido.stdlib.collections"
  BuiltinMemoryModuleName* = "eido.stdlib.memory"
  BuiltinTextModuleName* = "eido.stdlib.text"
  BuiltinRuntimeModuleName* = "eido.stdlib.runtime"
  BuiltinManagedGcModuleName* = "eido.stdlib.memory.managed"
  BuiltinRcModuleName* = "eido.stdlib.memory.rc"

  BuiltinStdlibManifestPath* = "<eido-sdk>/stdlib/module.yaml"
  BuiltinProcessManifestPath* = "<eido-sdk>/stdlib/process/module.yaml"
  BuiltinIoManifestPath* = "<eido-sdk>/stdlib/io/module.yaml"
  BuiltinStorageManifestPath* = "<eido-sdk>/stdlib/storage/module.yaml"
  BuiltinCollectionsManifestPath* = "<eido-sdk>/stdlib/collections/module.yaml"
  BuiltinMemoryManifestPath* = "<eido-sdk>/stdlib/memory/module.yaml"
  BuiltinTextManifestPath* = "<eido-sdk>/stdlib/text/module.yaml"
  BuiltinRuntimeManifestPath* = "<eido-sdk>/stdlib/runtime/module.yaml"
  BuiltinManagedGcManifestPath* =
    "<eido-sdk>/stdlib/memory/managed/module.yaml"
  BuiltinRcManifestPath* = "<eido-sdk>/stdlib/memory/rc/module.yaml"

  BuiltinStdlibManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/module.yaml"
  )
  BuiltinProcessManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/process/module.yaml"
  )
  BuiltinIoManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/io/module.yaml"
  )
  BuiltinStorageManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/storage/module.yaml"
  )
  BuiltinCollectionsManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/collections/module.yaml"
  )
  BuiltinMemoryManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/module.yaml"
  )
  BuiltinTextManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/text/module.yaml"
  )
  BuiltinRuntimeManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/runtime/module.yaml"
  )
  BuiltinManagedGcManifestSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/module.yaml"
  )
  BuiltinRcManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/rc/module.yaml"
  )

  BuiltinProcessSourcePath* = "eido://stdlib/process/process.eido"
  BuiltinConsoleSourcePath* = "eido://stdlib/io/console.eido"
  BuiltinStorageSourcePath* = "eido://stdlib/storage/storage.eido"
  BuiltinAlignmentSourcePath* = "eido://stdlib/storage/alignment.eido"
  BuiltinAlignedHeapBackingSourcePath* = "eido://stdlib/storage/aligned_heap_backing.eido"
  BuiltinArraySourcePath* = "eido://stdlib/collections/array.eido"
  BuiltinStorageArraySourcePath* = "eido://stdlib/collections/storage_array.eido"
  BuiltinArraysSourcePath* = "eido://stdlib/collections/arrays.eido"
  BuiltinStringRuntimeSourcePath* = "eido://stdlib/text/string_runtime.eido"
  BuiltinCopyRuntimeSourcePath* = "eido://stdlib/runtime/copy_runtime.eido"
  BuiltinManagedIdentityIndexSourcePath* =
    "eido://stdlib/memory/managed/identity_index.eido"
  BuiltinRcIdentityIndexSourcePath* =
    "eido://stdlib/memory/rc/identity_index.eido"
  BuiltinMemoryValueRegistrySourcePath* =
    "eido://stdlib/memory/managed/memory_value_registry.eido"
  BuiltinMemoryTypeRegistrySourcePath* =
    "eido://stdlib/memory/managed/memory_type_registry.eido"
  BuiltinManagedHeapAllocatorSourcePath* =
    "eido://stdlib/memory/managed/managed_heap_allocator.eido"
  BuiltinManagedGcRuntimeSourcePath* =
    "eido://stdlib/memory/managed/managed_gc_runtime.eido"
  BuiltinMemoryRuntimeSourcePath* =
    "eido://stdlib/memory/managed/memory_runtime.eido"
  BuiltinManagedPolicySourcePath* =
    "eido://stdlib/memory/managed/policy.eido"
  BuiltinRcValueRegistrySourcePath* =
    "eido://stdlib/memory/rc/rc_value_registry.eido"
  BuiltinRcTypeRegistrySourcePath* =
    "eido://stdlib/memory/rc/rc_type_registry.eido"
  BuiltinRcRuntimeSourcePath* = "eido://stdlib/memory/rc/rc_runtime.eido"
  BuiltinRcPolicyRuntimeSourcePath* =
    "eido://stdlib/memory/rc/rc_policy_runtime.eido"
  BuiltinRcPolicySourcePath* = "eido://stdlib/memory/rc/policy.eido"

  BuiltinProcessSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/process/process.eido"
  )
  BuiltinConsoleSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/io/console.eido"
  )
  BuiltinStorageSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/storage/storage.eido"
  )
  BuiltinAlignmentSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/storage/alignment.eido"
  )
  BuiltinAlignedHeapBackingSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/storage/aligned_heap_backing.eido"
  )
  BuiltinArraySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/collections/array.eido"
  )
  BuiltinStorageArraySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/collections/storage_array.eido"
  )
  BuiltinArraysSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/collections/arrays.eido"
  )
  BuiltinStringRuntimeSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/text/string_runtime.eido"
  )
  BuiltinCopyRuntimeSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/runtime/copy_runtime.eido"
  )
  BuiltinManagedIdentityIndexSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/identity_index.eido"
  )
  BuiltinRcIdentityIndexSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/rc/identity_index.eido"
  )
  BuiltinMemoryValueRegistrySource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/memory_value_registry.eido"
  )
  BuiltinMemoryTypeRegistrySource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/memory_type_registry.eido"
  )
  BuiltinManagedHeapAllocatorSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/managed_heap_allocator.eido"
  )
  BuiltinManagedGcRuntimeSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/managed_gc_runtime.eido"
  )
  BuiltinMemoryRuntimeSource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/memory_runtime.eido"
  )
  BuiltinManagedPolicySource* = staticRead(
    currentSourcePath().parentDir /
      "../../../stdlib/memory/managed/policy.eido"
  )
  BuiltinRcValueRegistrySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/rc/rc_value_registry.eido"
  )
  BuiltinRcTypeRegistrySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/rc/rc_type_registry.eido"
  )
  BuiltinRcRuntimeSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/rc/rc_runtime.eido"
  )
  BuiltinRcPolicyRuntimeSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/rc/rc_policy_runtime.eido"
  )
  BuiltinRcPolicySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/memory/rc/policy.eido"
  )

  BuiltinNativeSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_native.nim"
  )
  BuiltinSocketSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_native_sockets.nim"
  )
  BuiltinStorageSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_storage.nim"
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
  let payload = embeddedModule(manifestPath)
  let manifest = parseModuleManifest(payload.text, manifestPath)

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
    allowsExternalImplementation: manifest.allowsExternalImplementation,
    adopts: manifest.adopts
  )

  let ownIndex = modules.len
  modules.add spec

  for embedded in payload.sources:
    if not embedded.policy: continue
    if embedded.path in embeddedSourcePaths:
      raise newException(
        ValueError,
        "embedded stdlib source is declared more than once: " & embedded.path
      )
    embeddedSourcePaths.add embedded.path
    modules[ownIndex].policySources.add ModulePolicySource(
      entry: embedded.entry,
      path: embedded.path,
      text: embedded.text
    )

  for embedded in payload.sources:
    if embedded.policy: continue
    if embedded.path in embeddedSourcePaths:
      raise newException(
        ValueError,
        "embedded stdlib source is declared more than once: " & embedded.path
      )
    embeddedSourcePaths.add embedded.path
    modules[ownIndex].sourcePaths.add embedded.path
    let origin =
      if manifest.policySources.len > 0:
        soMemoryPolicyRuntime
      elif manifestPath == BuiltinTextManifestPath or
          manifestPath == BuiltinRuntimeManifestPath:
        soLanguageRuntime
      else:
        soOrdinary
    let runtimeCapability =
      if manifestPath == BuiltinTextManifestPath:
        lrcString
      elif manifestPath == BuiltinRuntimeManifestPath:
        lrcClassCopy
      else:
        lrcNone
    sources.add initSourceUnit(
      sources.len,
      embedded.path,
      embedded.text,
      canonical,
      origin,
      runtimeCapability,
      embeddedSdk = true
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

## Materializes the embedded SDK stdlib as a standalone library project.
## Documentation/tooling can inspect the SDK without injecting a second copy.
proc builtinStdlibProject*(
  target: projectModel.ProjectTarget = projectModel.ptLibrary
): projectModel.EidoProject =
  var sources: seq[SourceUnit]
  var modules: seq[ModuleSpec]
  var embeddedSourcePaths: seq[string]

  let rootModule = loadEmbeddedStdlibModule(
    BuiltinStdlibManifestPath,
    "",
    "stdlib",
    sources,
    modules,
    embeddedSourcePaths
  )
  if rootModule != BuiltinStdlibModuleName:
    raise newException(
      ValueError,
      "embedded stdlib root must resolve to '" & BuiltinStdlibModuleName & "'"
    )

  projectModel.initModuleProject(
    target,
    sources,
    modules,
    rootModule
  )

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
