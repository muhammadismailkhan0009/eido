import std/[os, sequtils, strutils, unittest]
import project/model
import project/modules/loader

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
    check project.modules.len == 2
    check project.modules[0].canonicalName == "shop"
    check project.modules[1].canonicalName == "shop.payments"
    check project.sources.len == 2
    check project.sources[0].moduleName == "shop"
    check project.sources[1].moduleName == "shop.payments"
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
