import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import pipeline/project_compiler
import project/model
import project/modules/loader
import tooling/compiler_service

## Exercises generic interfaces through real module qualification and visibility.
proc newGenericInterfaceProject(name: string): string =
  result = getTempDir() / ("eido_generic_interface_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "Generic interface module integration":
  test "a descendant implements a parent-owned generic interface with two parameters":
    let root = newGenericInterfaceProject("descendant")
    defer:
      if dirExists(root):
        removeDir(root)
    createDir(root / "implementation")

    writeFile(root / "module.yaml", """
      module: contracts
      sources:
        - Main.eido
      children:
        implementation: { path: implementation }
      dependencies: []
      exports:
        - Pair
      provides:
        Pair:
          by: implementation
      adopts:
        - implementation.Factory
    """)
    writeFile(root / "Main.eido", """
      interface Pair<First, Second> {
        function first() returns First;
        function second() returns Second;
      }
      function main() returns Int {
        var pair = Factory.create(42, true);
        if (pair.second()) { return pair.first(); }
        return 0;
      }
    """)
    writeFile(root / "implementation" / "module.yaml", """
      module: implementation
      sources:
        - InternalPair.eido
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    writeFile(root / "implementation" / "InternalPair.eido", """
      class InternalPair implements Pair<Int, Bool> {
        Int left;
        Bool right;
        function first() returns Int { return self.left; }
        function second() returns Bool { return self.right; }
      }
    """)
    writeFile(root / "implementation" / "Factory.eido", """
      class Factory {
        function create(Int left, Bool right) returns Pair<Int, Bool> {
          return InternalPair { left = left; right = right; };
        }
      }
    """)

    let project = loadModuleProject(root / "module.yaml", ptExecutable)
    let checked = checkProject(project)
    if not checked.success:
      for diagnostic in checked.diagnostics:
        checkpoint diagnostic.message
    check checked.success
    if checked.success:
      let generated = compileProjectToNim(project)
      let executable = root / "program"
      nimCompiler.compileWithNim(generated, executable)
      check execProcess(executable).strip() == "42"

  test "sibling modules cannot implement another sibling's closed generic interface":
    let root = newGenericInterfaceProject("closed")
    defer:
      if dirExists(root):
        removeDir(root)
    createDir(root / "contracts")
    createDir(root / "implementation")

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children:
        contracts: { path: contracts }
        implementation: { path: implementation }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "contracts" / "module.yaml", """
      module: contracts
      sources:
        - Pair.eido
      children: []
      dependencies: []
      exports:
        - Pair
      provides: {}
      adopts: []
    """)
    writeFile(root / "contracts" / "Pair.eido", """
      interface Pair<First, Second> {
        function first() returns First;
        function second() returns Second;
      }
    """)
    writeFile(root / "implementation" / "module.yaml", """
      module: implementation
      sources:
        - Impl.eido
      children: []
      dependencies:
        - contracts
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "implementation" / "Impl.eido", """
      class Invalid implements Pair<Int, Bool> {
        Int stored;
        Bool enabled;
        function first() returns Int { return self.stored; }
        function second() returns Bool { return self.enabled; }
      }
    """)

    let checked = checkProject(
      loadModuleProject(root / "module.yaml", ptExecutable)
    )
    check not checked.success
    check checked.diagnostics.len == 1
    if checked.diagnostics.len == 1:
      check "closed interface" in checked.diagnostics[0].message
