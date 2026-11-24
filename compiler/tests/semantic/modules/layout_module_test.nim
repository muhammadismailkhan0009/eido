import std/[os, strutils, unittest]
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
        - Selection.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() returns Int {
        var family = Family { father = 15; marker = 3; };
        return family.father;
      }
    """)
    writeFile(root / "Family.eido", "class Family { Int father; Byte marker; }")
    writeFile(root / "Layouts.eido", """
      layout Compact for Family {
        var shape = Layout.create();
        shape.field("marker");
        shape.field("father");
        shape.align(32);
        return shape;
      }
    """)

    writeFile(root / "Selection.eido", """
      LayoutPolicy.select("Family", "Compact");
    """)

    let checked = checkProject(loadModuleProject(root / "module.yaml", ptExecutable))
    check checked.success
    if checked.success:
      check checked.program.layouts.len == 1
      check checked.program.layouts[0].sourceName == "app.Compact"
      check checked.program.layouts[0].targetClass == "app.Family"
      # Module-qualified names also evaluate inside the actual compile-time phase.
      let generated = compileProject(
        loadModuleProject(root / "module.yaml", ptExecutable)
      )
      check generated.contains("_payload_size = int64(32)")
      check generated.contains("_alignment = int64(32)")
