## Embeds the foundational Eido standard-library declarations into the compiler.
## Normal module projects receive them through an implicit `eido.stdlib` dependency.

import std/os
import ../source/source_unit
import ../project/modules/[manifest_parser, model]

const
  BuiltinStdlibModuleName* = "eido.stdlib"
  BuiltinStdlibManifestPath* = "<eido-sdk>/stdlib/module.yaml"
  BuiltinStdlibManifestSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/module.yaml"
  )
  BuiltinProcessSourcePath* = "eido://stdlib/process.eido"
  BuiltinConsoleSourcePath* = "eido://stdlib/console.eido"
  BuiltinArenaSourcePath* = "eido://stdlib/arena.eido"
  BuiltinMemorySourcePath* = "eido://stdlib/memory.eido"
  BuiltinProcessSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/src/process.eido"
  )
  BuiltinConsoleSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/src/console.eido"
  )
  BuiltinArenaSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/src/arena.eido"
  )
  BuiltinMemorySource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/src/memory.eido"
  )
  BuiltinNativeSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_native.nim"
  )
  BuiltinStorageSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_storage.nim"
  )

## Resolves one manifest-owned stdlib source to its embedded compiler payload.
## The manifest controls membership; this mapping only supplies bytes for installed compilers.
proc embeddedStdlibSource(sourceEntry: string): tuple[path, text: string] =
  case sourceEntry
  of "src/process.eido":
    (BuiltinProcessSourcePath, BuiltinProcessSource)
  of "src/console.eido":
    (BuiltinConsoleSourcePath, BuiltinConsoleSource)
  of "src/arena.eido":
    (BuiltinArenaSourcePath, BuiltinArenaSource)
  of "src/memory.eido":
    (BuiltinMemorySourcePath, BuiltinMemorySource)
  else:
    raise newException(
      ValueError,
      "embedded stdlib manifest references unknown source '" & sourceEntry & "'"
    )

## Adds the manifest-defined embedded SDK stdlib and makes it an implicit root dependency.
## The compiler embeds the files for portability, but module metadata comes from module.yaml.
proc addBuiltinStdlib*(
  sources: var seq[SourceUnit],
  modules: var seq[ModuleSpec],
  rootModule: string
) =
  for moduleSpec in modules:
    if moduleSpec.canonicalName == BuiltinStdlibModuleName:
      raise newException(
        ValueError,
        "module identity '" & BuiltinStdlibModuleName & "' is reserved by the Eido SDK"
      )

  let manifest = parseModuleManifest(
    BuiltinStdlibManifestSource,
    BuiltinStdlibManifestPath
  )
  if manifest.name != "stdlib":
    raise newException(
      ValueError,
      "embedded stdlib manifest must declare module 'stdlib'"
    )
  if manifest.children.len > 0:
    raise newException(
      ValueError,
      "embedded stdlib child modules are not supported by the bootstrap loader"
    )

  var sourcePaths: seq[string]
  for sourceEntry in manifest.sources:
    let embedded = embeddedStdlibSource(sourceEntry)
    if embedded.path in sourcePaths:
      raise newException(
        ValueError,
        "embedded stdlib source is declared more than once: " & sourceEntry
      )
    sourcePaths.add embedded.path
    sources.add initSourceUnit(
      sources.len,
      embedded.path,
      embedded.text,
      BuiltinStdlibModuleName
    )

  var provisions: seq[ModuleProvision]
  for provision in manifest.provides:
    provisions.add ModuleProvision(
      contract: provision.contract,
      providerModule: provision.by
    )

  modules.add ModuleSpec(
    name: manifest.name,
    canonicalName: BuiltinStdlibModuleName,
    parentName: "",
    manifestPath: BuiltinStdlibManifestPath,
    directory: parentDir(BuiltinStdlibManifestPath),
    sourcePaths: sourcePaths,
    children: @[],
    dependencies: manifest.dependencies,
    exports: manifest.exports,
    provides: provisions,
    adopts: manifest.adopts
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
