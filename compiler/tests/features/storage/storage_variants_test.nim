import std/[strutils, unittest]
import support/feature_test_support

suite "Storage execution":
  test "reports target storage size and alignment through the unified API":
    let source = """
      function main() returns Int {
        return Storage<Int>.size() +
          Storage<Int>.alignment() +
          Storage<Byte>.size() +
          Storage<Byte>.alignment();
      }
    """

    check runNativeFeatureSource(source, "storage_layout_queries") == "18"

  test "allocates typed slots and assigns values independently":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(3);
        Storage<Int>.write(storage, 2, 7);
        var initial = Storage<Int>.read(storage, 2);
        Storage<Int>.write(storage, 1, 35);
        var updated = Storage<Int>.read(storage, 1);
        var size = Storage<Int>.capacity(storage);
        Storage<Int>.release(storage);
        return initial + updated + size;
      }
    """

    check runNativeFeatureSource(source, "storage_int_basic") == "45"

  test "supports String storage through the same generic API":
    let source = """
      function main() returns String {
        var storage = Storage<String>.allocate(2);
        Storage<String>.write(storage, 0, "stored");
        var value = Storage<String>.read(storage, 0);
        Storage<String>.release(storage);
        return value;
      }
    """

    check runNativeFeatureSource(source, "storage_string_basic") == "stored"

  test "rejects out-of-bounds access at runtime":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(2);
        return Storage<Int>.read(storage, 2);
      }
    """

    let execution = runFailingNativeFeatureSource(
      source,
      "storage_bounds_failure"
    )
    check execution.exitCode != 0
    check "Eido storage index out of bounds" in execution.output

  test "borrowed storage remains live after a helper call":
    let source = """
      function first(Storage<Int> storage) returns Int {
        return Storage<Int>.read(storage, 0);
      }

      function main() returns Int {
        var storage = Storage<Int>.allocate(1);
        Storage<Int>.write(storage, 0, 42);
        var value = first(storage);
        Storage<Int>.release(storage);
        return value;
      }
    """

    check runNativeFeatureSource(source, "storage_borrow") == "42"

  test "an owning class field can release its raw storage":
    let source = """
      class Buffer {
        Storage<Int> storage;

        function close() {
          Storage<Int>.release(self.storage);
        }
      }

      function main() returns Int {
        var buffer = Buffer {
          storage = Storage<Int>.allocate(2);
        };
        buffer.close();
        return 9;
      }
    """

    check runNativeFeatureSource(source, "storage_field_release") == "9"

  test "a class-owned Storage field releases its descriptor in place":
    let source = """
      class Buffer {
        Storage<Int> Buffer.storage = Storage<Int>.allocate(1);

        function useAndClose() returns Int {
          Storage<Int>.write(Buffer.storage, 0, 42);
          var value = Storage<Int>.read(Buffer.storage, 0);
          Storage<Int>.release(Buffer.storage);
          return value;
        }
      }

      function main() returns Int {
        return Buffer.useAndClose();
      }
    """

    check runNativeFeatureSource(source, "storage_class_owned_release") == "42"

  test "creates allocation-free typed views over byte storage":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(4, 8);
        var ints = Storage<Int>.view(raw, 0);
        Storage<Int>.write(ints, 1, 55);
        var resultValue = Storage<Int>.read(ints, 1);
        Storage<Byte>.release(raw);
        return resultValue;
      }
    """

    check runNativeFeatureSource(source, "storage_typed_view") == "55"


  test "creates typed views at byte offsets inside one raw block":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(1, 16);
        var first = Storage<Int>.viewAt(raw, 0);
        var second = Storage<Int>.viewAt(raw, 8);
        Storage<Int>.write(first, 0, 20);
        Storage<Int>.write(second, 0, 22);
        var resultValue = Storage<Int>.read(first, 0) +
          Storage<Int>.read(second, 0);
        Storage<Byte>.release(raw);
        return resultValue;
      }
    """

    check runNativeFeatureSource(source, "storage_byte_offset_view") == "42"

  test "can explicitly recover raw Storage ownership from its address":
    let source = """
      function main() returns Int {
        var original = Storage<Byte>.allocateRaw(1, 8);
        var address = Storage<Byte>.address(original);
        var recovered = Storage<Byte>.adoptAddress(address, 1, 8);
        Storage<Byte>.release(recovered);
        return 42;
      }
    """

    check runNativeFeatureSource(source, "storage_adopt_address") == "42"

  test "slices typed storage without allocating backing memory":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(4);
        Storage<Int>.write(storage, 2, 77);
        var tail = Storage<Int>.slice(storage, 2, 2);
        var value = Storage<Int>.read(tail, 0);
        Storage<Int>.release(storage);
        return value;
      }
    """

    check runNativeFeatureSource(source, "storage_slice") == "77"


  test "rejects misaligned typed views over raw byte storage":
    let source = """
      function main() {
        var raw = Storage<Byte>.allocateRaw(4, 9);
        var ints = Storage<Int>.view(raw, 1);
      }
    """

    let execution = runFailingNativeFeatureSource(
      source,
      "storage_view_alignment_failure"
    )
    check execution.exitCode != 0
    check "Eido storage view is misaligned" in execution.output

  test "rejects typed views whose type does not fit one raw block":
    let source = """
      function main() {
        var raw = Storage<Byte>.allocateRaw(1, 4);
        var ints = Storage<Int>.view(raw, 0);
      }
    """

    let execution = runFailingNativeFeatureSource(
      source,
      "storage_view_fit_failure"
    )
    check execution.exitCode != 0
    check "does not fit raw allocation block" in execution.output

  test "fromAddress creates consecutive external raw blocks without freeing them":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.fromAddress(0, 0, 64);
        var size = Storage<Byte>.capacity(raw);
        Storage<Byte>.release(raw);
        return size;
      }
    """

    check runNativeFeatureSource(source, "storage_from_address") == "0"
