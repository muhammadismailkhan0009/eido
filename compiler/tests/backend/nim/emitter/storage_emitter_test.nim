import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import project/model
import project/modules/loader
import stdlib/builtin_sources
import tooling/compiler_service

suite "Storage emission":
  test "raw Storage remains the single physical allocator":
    check BuiltinStorageSupportSource.count("alloc0(") == 1
    check "proc eidoStorageAllocateRaw*" in BuiltinStorageSupportSource

  test "real projects implement typed Storage through Eido over raw Storage Byte":
    let root = getTempDir() / ("eido_storage_emitter_" & $getCurrentProcessId())
    let outputPath = root / "storageapp"
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
        var typed = Storage<Int>.allocate(2);
        Storage<Int>.write(typed, 0, 21);
        var first = Storage<Int>.slice(typed, 0, 1);

        var raw = Storage<Byte>.allocateRaw(2, 16);
        var block = Storage<Int>.view(raw, 1);
        Storage<Int>.write(block, 0, 10);
        var inside = Storage<Int>.viewAt(raw, 8);
        Storage<Int>.write(inside, 0, 11);

        var value = Storage<Int>.read(first, 0) +
            Storage<Int>.read(block, 0) +
            Storage<Int>.read(inside, 0);
        Storage<Int>.release(typed);
        Storage<Byte>.release(raw);
        return value;
      }
    """)

    let generated = compileProject(
      loadModuleProject(root / "module.yaml", ptExecutable)
    )

    check "import eido_storage" in generated
    check " = EidoStorage[int64]" in generated
    check " = EidoStorage[int8]" in generated
    check "eidoStorageAllocateRaw" in generated
    check "eidoStorageFromRaw[int64]" in generated
    check "eidoStorageRaw[int64]" in generated
    check "eidoStorageRead[int64]" in generated
    check "eidoStorageWrite[int64]" in generated

    # Public typed operations are ordinary Eido method bodies, not native Storage<T> glue.
    check "eido_method_" in generated
    check "eidoStorageAllocate[int64]" notin generated
    check "eidoStorageView[int64]" notin generated
    check "eidoStorageSlice[int64]" notin generated
    check "eidoStorageRelease[int64]" notin generated

    # Physical allocation details remain in the native support module, never generated source.
    check "alloc0(" notin generated
    check "dealloc(" notin generated
    check "ptr UncheckedArray" notin generated
    check "seq[int64]" notin generated
    check "newSeq" notin generated

    nimCompiler.compileWithNim(generated, outputPath)
    check execProcess(outputPath).strip() == "42"
