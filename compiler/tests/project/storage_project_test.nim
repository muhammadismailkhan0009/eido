import std/[os, unittest]
import std/strutils
import project/model
import source/source_unit
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

  test "compiler Storage representation bridges are not public application API":
    let root = getTempDir() / ("eido_storage_private_bridge_" & $getCurrentProcessId())
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
        var storage = Storage<Int>.allocate(1);
        return Storage<Int>.compilerRead(storage, 0);
      }
    """)

    let checked = checkProject(
      loadModuleProject(root / "module.yaml", ptExecutable)
    )
    check not checked.success
    check checked.diagnostics.len == 1
    check "is not public API" in checked.diagnostics[0].message


  test "a source path cannot impersonate an embedded SDK caller":
    for path in ["/tmp/user/stdlib/storage/storage.eido",
                 "eido://stdlib/runtime/copy_runtime.eido",
                 "eido://stdlib/memory/fake.eido"]:
      let project = initProject(ptExecutable, @[
        initSourceUnit(0, path, """
          function main() {
            Storage<Byte>.compilerReleaseNativeAddress(4096);
          }
        """)
      ])
      let checked = checkProject(project)
      check not checked.success
      check checked.diagnostics.len > 0
      check "is not public API" in checked.diagnostics[0].message
