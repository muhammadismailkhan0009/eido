import std/[os, sequtils, strutils, unittest]
import project/model
import project/modules/loader
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
    check project.modules.len == 7
    check project.modules[0].canonicalName == "shop"
    check project.modules[1].canonicalName == "shop.payments"

    check project.modules[2].canonicalName == BuiltinStdlibModuleName
    check project.modules[2].name == "stdlib"
    check project.modules[2].manifestPath == BuiltinStdlibManifestPath
    check project.modules[2].sourcePaths.len == 0
    check project.modules[2].children == @[
      BuiltinProcessModuleName,
      BuiltinIoModuleName,
      BuiltinMemoryModuleName
    ]
    check project.modules[2].exports == @[
      "process.Process",
      "io.Console",
      "memory.Memory"
    ]

    check project.modules[3].canonicalName == BuiltinProcessModuleName
    check project.modules[3].sourcePaths == @[BuiltinProcessSourcePath]
    check project.modules[4].canonicalName == BuiltinIoModuleName
    check project.modules[4].sourcePaths == @[BuiltinConsoleSourcePath]
    check project.modules[5].canonicalName == BuiltinMemoryModuleName
    check project.modules[5].sourcePaths == @[
      BuiltinMemorySourcePath,
      BuiltinArenaSourcePath
    ]
    check project.modules[5].children == @[BuiltinManagedGcModuleName]
    check project.modules[6].canonicalName == BuiltinManagedGcModuleName
    check project.modules[6].sourcePaths == @[
      BuiltinManagedGcNativeSourcePath,
      BuiltinManagedGcRuntimeSourcePath
    ]
    check project.modules[6].exports.len == 0

    check BuiltinStdlibModuleName in project.modules[0].dependencies
    check project.sources.len == 8
    check project.sources[0].moduleName == "shop"
    check project.sources[1].moduleName == "shop.payments"
    check project.sources[2].moduleName == BuiltinProcessModuleName
    check project.sources[3].moduleName == BuiltinIoModuleName
    check project.sources[4].moduleName == BuiltinMemoryModuleName
    check project.sources[5].moduleName == BuiltinMemoryModuleName
    check project.sources[6].moduleName == BuiltinManagedGcModuleName
    check project.sources[7].moduleName == BuiltinManagedGcModuleName
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
