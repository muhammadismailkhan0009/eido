import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import pipeline/project_compiler
import project/model
import project/modules/loader
import tooling/compiler_service

suite "Collections project integration":
  test "Array<Int> is available from the implicit stdlib and uses Storage backing":
    let root = getTempDir() / ("eido_array_project_" & $getCurrentProcessId())
    let outputPath = root / "array_app"
    if dirExists(root):
      removeDir(root)
    createDir(root)
    defer:
      removeDir(root)

    writeFile(root / "module.yaml", """
      module: arrayapp
      sources:
        - Main.eido
        - Functions.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() returns Int {
        var values = Arrays<Int>.create(3);
        values.setAt(0, 40);
        values.setAt(1, 2);
        var resultValue = first(values) + values.get(1) + values.size();
        values.release();
        return resultValue;
      }
    """)
    writeFile(root / "Functions.eido", """
      function first(Array<Int> values) returns Int {
        return values.get(0);
      }
    """)

    let project = loadModuleProject(root / "module.yaml", ptExecutable)
    let generated = compileProjectToNim(project)
    nimCompiler.compileWithNim(generated, outputPath)

    check execProcess(outputPath).strip() == "45"

  test "StorageArray implementation remains internal to the collections module":
    let root = getTempDir() / ("eido_array_visibility_" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    createDir(root)
    defer:
      removeDir(root)

    writeFile(root / "module.yaml", """
      module: arrayvisibility
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() {
        var hidden = StorageArray<Int> {
          storage = Storage<Int>.allocate(1);
        };
      }
    """)

    let checked = checkProject(
      loadModuleProject(root / "module.yaml", ptExecutable)
    )
    check not checked.success
