import std/[os, unittest]
import project/model
import project/modules/loader
import tooling/compiler_service

suite "Storage project integration":
  test "Storage is available in a normal module project without an explicit import":
    let root = getTempDir() / ("eido_storage_project_" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    createDir(root)
    defer:
      removeDir(root)

    writeFile(root / "module.yaml", """
      module: storageapp
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() returns Int {
        var storage = Storage<Int>.allocate(2);
        Storage<Int>.write(storage, 1, 42);
        var value = Storage<Int>.read(storage, 1);
        Storage<Int>.release(storage);
        return value;
      }
    """)

    let checked = checkProject(
      loadModuleProject(root / "module.yaml", ptExecutable)
    )
    check checked.success

  test "Arena is available through the implicit stdlib public surface":
    let root = getTempDir() / ("eido_arena_project_" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    createDir(root)
    defer:
      removeDir(root)

    writeFile(root / "module.yaml", """
      module: arenaapp
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() returns Int {
        var arena = Arena<Int>.create(4);
        var values = arena.allocate(2);
        Storage<Int>.write(values, 1, 42);
        var resultValue = Storage<Int>.read(values, 1);
        arena.release();
        return resultValue;
      }
    """)

    let checked = checkProject(
      loadModuleProject(root / "module.yaml", ptExecutable)
    )
    check checked.success
