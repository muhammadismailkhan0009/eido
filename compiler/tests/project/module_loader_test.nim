import std/[os, sequtils, strutils, unittest]
import project/model
import project/modules/loader
import source/source_unit
import stdlib/builtin_sources

## Documents the freshDir module helper behavior.
proc freshDir(name: string): string =
  result = getTempDir() / ("eido_module_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "Module project loading":
  test "loads explicit sources and canonical parent child identities":
    let root = freshDir("load")
    defer:
      removeDir(root)

    createDir(root / "payments")
    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        payments:
          path: payments
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "Ignored.eido", "function ignored() {}")

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - Payments.eido
      children: []
      dependencies: []
      exports:
        - Payments
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Payments.eido", """
      class Payments {
        function version() returns Int { return 1; }
      }
    """)

    let project = loadModuleProject(root / "module.yaml", ptExecutable)

    check project.rootModule == "shop"
    check project.modules.len == 12
    check project.modules[0].canonicalName == "shop"
    check project.modules[1].canonicalName == "shop.payments"

    check project.modules[2].canonicalName == BuiltinStdlibModuleName
    check project.modules[2].name == "stdlib"
    check project.modules[2].manifestPath == BuiltinStdlibManifestPath
    check project.modules[2].sourcePaths.len == 0
    check project.modules[2].children == @[
      BuiltinProcessModuleName,
      BuiltinIoModuleName,
      BuiltinStorageModuleName,
      BuiltinCollectionsModuleName,
      BuiltinMemoryModuleName,
      BuiltinTextModuleName,
      BuiltinRuntimeModuleName
    ]
    check project.modules[2].exports == @[
      "process.Process",
      "io.Console",
      "storage.Storage",
      "collections.Array",
      "collections.Arrays"
    ]

    check project.modules[3].canonicalName == BuiltinProcessModuleName
    check project.modules[3].sourcePaths == @[BuiltinProcessSourcePath]
    check project.modules[4].canonicalName == BuiltinIoModuleName
    check project.modules[4].sourcePaths == @[BuiltinConsoleSourcePath]
    check project.modules[5].canonicalName == BuiltinStorageModuleName
    check project.modules[5].sourcePaths == @[BuiltinStorageSourcePath]
    check project.modules[5].exports == @["Storage"]
    check project.modules[6].canonicalName == BuiltinCollectionsModuleName
    check project.modules[6].sourcePaths == @[
      BuiltinArraySourcePath,
      BuiltinStorageArraySourcePath,
      BuiltinArraysSourcePath
    ]
    check project.modules[6].exports == @["Array", "Arrays"]
    check project.modules[7].canonicalName == BuiltinMemoryModuleName
    check project.modules[7].sourcePaths.len == 0
    check project.modules[7].children == @[
      BuiltinManagedGcModuleName,
      BuiltinRcModuleName
    ]
    check project.modules[8].canonicalName == BuiltinManagedGcModuleName
    check project.modules[8].sourcePaths == @[
      BuiltinMemoryValueRegistrySourcePath,
      BuiltinMemoryTypeRegistrySourcePath,
      BuiltinManagedHeapAllocatorSourcePath,
      BuiltinManagedIdentityIndexSourcePath,
      BuiltinManagedGcRuntimeSourcePath,
      BuiltinMemoryRuntimeSourcePath
    ]
    check project.modules[8].exports.len == 0
    check project.modules[8].policySources.len == 1
    check project.modules[8].policySources[0].entry == "policy.eido"
    check project.modules[8].policySources[0].path == BuiltinManagedPolicySourcePath
    check "MemoryPolicy.objectAcquire" in project.modules[8].policySources[0].text
    check project.modules[9].canonicalName == BuiltinRcModuleName
    check project.modules[9].sourcePaths == @[
      BuiltinRcValueRegistrySourcePath,
      BuiltinRcTypeRegistrySourcePath,
      BuiltinRcIdentityIndexSourcePath,
      BuiltinRcRuntimeSourcePath,
      BuiltinRcPolicyRuntimeSourcePath
    ]
    check project.modules[9].exports.len == 0
    check project.modules[9].policySources.len == 1
    check project.modules[9].policySources[0].entry == "policy.eido"
    check project.modules[9].policySources[0].path == BuiltinRcPolicySourcePath
    check "MemoryPolicy.objectAcquire" in project.modules[9].policySources[0].text
    check project.modules[10].canonicalName == BuiltinTextModuleName
    check project.modules[10].sourcePaths == @[BuiltinStringRuntimeSourcePath]
    check project.modules[10].exports.len == 0
    check project.modules[11].canonicalName == BuiltinRuntimeModuleName
    check project.modules[11].sourcePaths == @[BuiltinCopyRuntimeSourcePath]
    check project.modules[11].exports.len == 0

    check BuiltinStdlibModuleName in project.modules[0].dependencies
    check project.sources.len == 21
    check project.sources[0].moduleName == "shop"
    check project.sources[1].moduleName == "shop.payments"
    check project.sources[2].moduleName == BuiltinProcessModuleName
    check project.sources[3].moduleName == BuiltinIoModuleName
    check project.sources[4].moduleName == BuiltinStorageModuleName
    for index in 5 .. 7:
      check project.sources[index].moduleName == BuiltinCollectionsModuleName
    for index in 8 .. 13:
      check project.sources[index].moduleName == BuiltinManagedGcModuleName
    for index in 14 .. 18:
      check project.sources[index].moduleName == BuiltinRcModuleName
    check project.sources[19].moduleName == BuiltinTextModuleName
    check project.sources[20].moduleName == BuiltinRuntimeModuleName
    for index in 0 .. 7:
      check project.sources[index].origin == soOrdinary
      check project.sources[index].runtimeCapability == lrcNone
    for index in 8 .. 18:
      check project.sources[index].origin == soMemoryPolicyRuntime
      check project.sources[index].runtimeCapability == lrcNone
    check project.sources[19].origin == soLanguageRuntime
    check project.sources[19].runtimeCapability == lrcString
    check project.sources[20].origin == soLanguageRuntime
    check project.sources[20].runtimeCapability == lrcClassCopy
    check project.sources.allIt(not it.path.endsWith("Ignored.eido"))

  test "rejects dependency cycles":
    let root = freshDir("cycle")
    defer:
      removeDir(root)

    createDir(root / "a")
    createDir(root / "b")
    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        a: { path: a }
        b: { path: b }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "a" / "module.yaml", """
      module: a
      sources:
        - A.eido
      children: []
      dependencies:
        - b
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "a" / "A.eido", "class A {}")

    writeFile(root / "b" / "module.yaml", """
      module: b
      sources:
        - B.eido
      children: []
      dependencies:
        - a
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "b" / "B.eido", "class B {}")

    expect ValueError:
      discard loadModuleProject(root / "module.yaml", ptExecutable)
