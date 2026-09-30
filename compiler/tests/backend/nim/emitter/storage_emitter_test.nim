import std/[strutils, unittest]
import support/compiler_test_support
import stdlib/builtin_sources

suite "Storage emission":
  test "typed allocation composes the single raw physical allocator":
    check BuiltinStorageSupportSource.count("alloc0(") == 1
    check "let raw = eidoStorageAllocateRaw(allocations, int64(sizeof(T)))" in
      BuiltinStorageSupportSource

  test "emits concrete typed storage support without external native ABI":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(4);
        Storage<Int>.write(storage, 2, 41);
        return Storage<Int>.read(storage, 2);
      }
    """

    let generated = emitSource(source)

    check "import eido_storage" in generated
    check " = EidoStorage[int64]" in generated
    check " = EidoStorage[int8]" in generated
    check "eidoStorageAllocate[int64]" in generated
    check "eidoStorageAllocateRaw" in generated
    check "eidoStorageFromAddress" in generated
    check "eidoStorageView[int64]" in generated
    check "eidoStorageSlice[int64]" in generated
    check "eidoStorageRelease[int64]" in generated
    check "eidoStorageSize[int64]" in generated
    check "eidoStorageAlignment[int64]" in generated
    check "alloc0(" notin generated
    check "dealloc(" notin generated
    check "ptr UncheckedArray" notin generated
    check "seq[int64]" notin generated
    check "newSeq" notin generated
    check "new(result)" notin generated
    check " = ref object" notin generated
    check "import eido_native" notin generated
