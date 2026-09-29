## Embeds the foundational Eido standard-library declarations into the compiler.
## Normal module projects receive them through an implicit `eido.stdlib` dependency.

import std/os
import ../source/source_unit
import ../project/modules/model

const
  BuiltinStdlibModuleName* = "eido.stdlib"
  BuiltinStdlibManifestPath* = "<eido-sdk>/stdlib/module.yaml"
  BuiltinProcessSourcePath* = "eido://stdlib/process.eido"
  BuiltinConsoleSourcePath* = "eido://stdlib/console.eido"
  BuiltinProcessSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/src/process.eido"
  )
  BuiltinConsoleSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/src/console.eido"
  )
  BuiltinNativeSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_native.nim"
  )
  BuiltinStorageSupportSource* = staticRead(
    currentSourcePath().parentDir / "../../../stdlib/native/nim/eido_storage.nim"
  )

## Adds the embedded SDK stdlib module and makes it an implicit root dependency.
## Child modules inherit that dependency through the existing module visibility rules.
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

  sources.add initSourceUnit(
    sources.len,
    BuiltinProcessSourcePath,
    BuiltinProcessSource,
    BuiltinStdlibModuleName
  )
  sources.add initSourceUnit(
    sources.len,
    BuiltinConsoleSourcePath,
    BuiltinConsoleSource,
    BuiltinStdlibModuleName
  )

  modules.add ModuleSpec(
    name: "stdlib",
    canonicalName: BuiltinStdlibModuleName,
    parentName: "",
    manifestPath: BuiltinStdlibManifestPath,
    directory: "",
    sourcePaths: @[BuiltinProcessSourcePath, BuiltinConsoleSourcePath],
    children: @[],
    dependencies: @[],
    exports: @["Process", "Console"],
    provides: @[],
    adopts: @[]
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
