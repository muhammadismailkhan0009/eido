import std/[strutils, unittest]
import support/feature_test_support
import stdlib/builtin_sources

suite "Layered Eido aligned allocation":
  test "Storage is independent of AlignedHeapBacking, which uses raw Storage":
    check "AlignedHeapBacking.allocate(" notin BuiltinStorageSource
    check "Storage<Byte>.allocateRaw" in BuiltinAlignedHeapBackingSource
    check "Storage<Byte>.compilerRebaseOwned" in BuiltinAlignedHeapBackingSource
    check "function releaseAddress(" in BuiltinAlignedHeapBackingSource

  test "private SDK heap backing cannot be invoked from user code":
    let source = """
      function main() {
        var raw = AlignedHeapBacking.allocate(1, 64, 64);
        AlignedHeapBacking.releaseAddress(Storage<Byte>.address(raw));
      }
    """
    expect ValueError:
      discard runNativeFeatureSource(source, "private_heap_backing_denied")

  test "Alignment is independent of heap allocation":
    check "Storage<" notin BuiltinAlignmentSource
    check "function alignUp(" in BuiltinAlignmentSource
    check "function isAligned(" in BuiltinAlignmentSource
    check "function padding(" in BuiltinAlignmentSource
