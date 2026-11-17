import std/[os, unittest]
import project/model
import project/modules/loader
import tooling/compiler_service

suite "Layout declarations in modules":
  test "resolves the layout target and name to canonical module identities":
    let root = getTempDir() / ("eido_layout_module_" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    createDir(root)
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
        - Family.eido
        - Layouts.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "Family.eido", "class Family { Int father; }")
    writeFile(root / "Layouts.eido", """
      layout Compact for Family {
        var shape = Layout.create();
        shape.field("father");
        return shape;
      }
    """)

    let checked = checkProject(loadModuleProject(root / "module.yaml", ptExecutable))
    check checked.success
    if checked.success:
      check checked.program.layouts.len == 1
      check checked.program.layouts[0].sourceName == "app.Compact"
      check checked.program.layouts[0].targetClass == "app.Family"
