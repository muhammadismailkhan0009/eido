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
      "storage.Alignment",
      "collections.Array",
      "collections.Arrays"
    ]

    check project.modules[3].canonicalName == BuiltinProcessModuleName
    check project.modules[3].sourcePaths == @[BuiltinProcessSourcePath]
    check project.modules[4].canonicalName == BuiltinIoModuleName
    check project.modules[4].sourcePaths == @[BuiltinConsoleSourcePath]
    check project.modules[5].canonicalName == BuiltinStorageModuleName
    check project.modules[5].sourcePaths == @[
      BuiltinStorageSourcePath, BuiltinAlignmentSourcePath, BuiltinAlignedHeapBackingSourcePath
    ]
    check project.modules[5].exports == @["Storage", "Alignment"]
    check project.modules[5].dependencies.len == 0
    check BuiltinStorageModuleName in project.modules[7].dependencies
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
    check project.sources.len == 23
    check project.sources[0].moduleName == "shop"
    check project.sources[1].moduleName == "shop.payments"
    check project.sources[2].moduleName == BuiltinProcessModuleName
    check project.sources[3].moduleName == BuiltinIoModuleName
    for index in 4 .. 6:
      check project.sources[index].moduleName == BuiltinStorageModuleName
    for index in 7 .. 9:
      check project.sources[index].moduleName == BuiltinCollectionsModuleName
    for index in 10 .. 15:
      check project.sources[index].moduleName == BuiltinManagedGcModuleName
    for index in 16 .. 20:
      check project.sources[index].moduleName == BuiltinRcModuleName
    check project.sources[21].moduleName == BuiltinTextModuleName
    check project.sources[22].moduleName == BuiltinRuntimeModuleName
    for index in 0 .. 9:
      check project.sources[index].origin == soOrdinary
      check project.sources[index].runtimeCapability == lrcNone
    for index in 10 .. 20:
      check project.sources[index].origin == soMemoryPolicyRuntime
      check project.sources[index].runtimeCapability == lrcNone
    check project.sources[21].origin == soLanguageRuntime
    check project.sources[21].runtimeCapability == lrcString
    check project.sources[22].origin == soLanguageRuntime
    check project.sources[22].runtimeCapability == lrcClassCopy
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

  test "directory sources discover deterministically without crossing manifests or policy roles":
    let root = freshDir("directory_sources")
    defer: removeDir(root)
    for dir in ["a/nested", "b", "child", "other"]:
      createDir(root / dir)
    writeFile(root / "module.yaml", "module: app\nsources: [.]\nchildren:\n  child: { path: child }\npolicySources: [policy.eido]\n")
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "a/nested/First.eido", "class First { Int value; }")
    writeFile(root / "b/Second.eido", "class Second { Int value; }")
    writeFile(root / "policy.eido", "function main() {}")
    writeFile(root / "b/ignore.txt", "not source")
    writeFile(root / "child/module.yaml", "module: child\nsources: [.]\n")
    writeFile(root / "child/Child.eido", "class Child { Int value; }")
    writeFile(root / "other/module.yaml", "module: other\nsources: [.]\n")
    writeFile(root / "other/Unregistered.eido", "class Unregistered { Int value; }")
    let project = loadModuleProject(root / "module.yaml", ptLibrary)
    check project.modules[0].sourcePaths == @[root / "Main.eido", root / "a/nested/First.eido", root / "b/Second.eido"]
    check project.modules[0].policySources.len == 1
    check project.modules[1].sourcePaths == @[root / "child/Child.eido"]
    check project.sources.allIt(not it.path.endsWith("Unregistered.eido"))

  test "rejects duplicate directory discovery and explicit child source registration":
    let root = freshDir("duplicate_directory_sources")
    defer: removeDir(root)
    createDir(root / "logic")
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "logic/Helper.eido", "class Helper { Int value; }")
    writeFile(root / "module.yaml", "module: app\nsources: [., logic]\n")
    expect ValueError:
      discard loadModuleProject(root / "module.yaml", ptExecutable)
    writeFile(root / "logic/module.yaml", "module: logic\nsources: [.]\n")
    writeFile(root / "module.yaml", "module: app\nsources: [Main.eido, logic/Helper.eido]\nchildren:\n  logic: { path: logic }\n")
    expect ValueError:
      discard loadModuleProject(root / "module.yaml", ptExecutable)

  test "a logical child may physically enclose its owning manifest":
    let root = freshDir("ancestor_child")
    defer: removeDir(root)
    createDir(root / "tests")
    writeFile(root / "module.yaml", "module: package\nsources: [.]\n")
    writeFile(root / "Package.eido", "class Package { Int value; }")
    writeFile(root / "tests/Main.eido", "function main() {}")
    let testsManifest = root / "tests/module.yaml"

    for sources in ["[Main.eido]", "[.]"]:
      writeFile(testsManifest,
        "module: tests\nsources: " & sources &
        "\nchildren:\n  package: { path: .. }\n")
      let project = loadModuleProject(testsManifest, ptExecutable)
      check project.modules[0].sourcePaths == @[root / "tests/Main.eido"]
      check project.modules[1].canonicalName == "tests.package"
      check project.modules[1].sourcePaths == @[root / "Package.eido"]

    # The exception permits only sources owned by the test manifest, not
    # directly claiming the enclosing package's implementation.
    writeFile(testsManifest,
      "module: tests\nsources: [Main.eido, ../Package.eido]\n" &
      "children:\n  package: { path: .. }\n")
    expect ValueError:
      discard loadModuleProject(testsManifest, ptExecutable)
