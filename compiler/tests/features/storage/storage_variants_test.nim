import std/[strutils, unittest]
import support/feature_test_support

import support/feature_batch_support

suite "Storage execution":
  test "successful native Storage scenarios (batched)":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(
        name: "reports target storage size and alignment through the unified API",
        source: """
      function main() returns Int {
        return Storage<Int>.size() +
          Storage<Int>.alignment() +
          Storage<Byte>.size() +
          Storage<Byte>.alignment();
      }
    """,
        expected: "18"
      ),
      NativeFeatureCase(
        name: "allocates typed slots and assigns values independently",
        source: """
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
    """,
        expected: "45"
      ),
      NativeFeatureCase(
        name: "supports String storage through the same generic API",
        source: """
      function main() returns String {
        var storage = Storage<String>.allocate(2);
        Storage<String>.write(storage, 0, "stored");
        var value = Storage<String>.read(storage, 0);
        Storage<String>.release(storage);
        return value;
      }
    """,
        expected: "stored"
      ),
      NativeFeatureCase(
        name: "borrowed storage remains live after a helper call",
        source: """
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
    """,
        expected: "42"
      ),
      NativeFeatureCase(
        name: "an owning class field can release its raw storage",
        source: """
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
    """,
        expected: "9"
      ),
      NativeFeatureCase(
        name: "a class-owned Storage field releases its descriptor in place",
        source: """
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
    """,
        expected: "42"
      ),
      NativeFeatureCase(
        name: "creates allocation-free typed views over byte storage",
        source: """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(4, 8);
        var ints = Storage<Int>.view(raw, 0);
        Storage<Int>.write(ints, 1, 55);
        var resultValue = Storage<Int>.read(ints, 1);
        Storage<Byte>.release(raw);
        return resultValue;
      }
    """,
        expected: "55"
      ),
      NativeFeatureCase(
        name: "creates typed views at byte offsets inside one raw block",
        source: """
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
    """,
        expected: "42"
      ),
      NativeFeatureCase(
        name: "borrowed address is usable without adopting native ownership",
        source: """
      function main() returns Int {
        var original = Storage<Byte>.allocateRaw(1, 8);
        var address = Storage<Byte>.address(original);
        var borrowed = Storage<Byte>.borrowAddress(address, 1, 8);
        Storage<Byte>.write(borrowed, 0, 7);
        var value = Storage<Int>.read(Storage<Int>.view(original, 0), 0);
        Storage<Byte>.release(original);
        return value;
      }
    """,
        expected: "7"
      ),
      NativeFeatureCase(
        name: "slices typed storage without allocating backing memory",
        source: """
      function main() returns Int {
        var storage = Storage<Int>.allocate(4);
        Storage<Int>.write(storage, 2, 77);
        var tail = Storage<Int>.slice(storage, 2, 2);
        var value = Storage<Int>.read(tail, 0);
        Storage<Int>.release(storage);
        return value;
      }
    """,
        expected: "77"
      ),
      NativeFeatureCase(
        name: "borrowAddress creates non-owning raw storage over an existing address",
        source: """
      function main() returns Int {
        var owner = Storage<Byte>.allocateRaw(1, 8);
        var address = Storage<Byte>.address(owner);
        var borrowed = Storage<Byte>.borrowAddress(address, 1, 8);
        var borrowedInt = Storage<Int>.view(borrowed, 0);
        Storage<Int>.write(borrowedInt, 0, 42);
        var ownerInt = Storage<Int>.view(owner, 0);
        var value = Storage<Int>.read(ownerInt, 0);
        Storage<Byte>.release(owner);
        return value;
      }
    """,
        expected: "42"
      )
    ], "storage_variants_test")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

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

  test "typed release invalidates an instance field descriptor":
    let source = """
      class Buffer {
        Storage<Int> storage;

        function close() {
          Storage<Int>.release(self.storage);
        }
      }

      function main() {
        var buffer = Buffer {
          storage = Storage<Int>.allocate(1);
        };
        buffer.close();
        buffer.close();
      }
    """

    let execution = runFailingNativeFeatureSource(
      source,
      "storage_instance_field_double_release"
    )
    check execution.exitCode != 0
    check "Eido storage access after release" in execution.output

  test "typed release invalidates a class-owned field descriptor":
    let source = """
      class Buffer {
        Storage<Int> Buffer.storage = Storage<Int>.allocate(1);

        function close() {
          Storage<Int>.release(Buffer.storage);
        }
      }

      function main() {
        Buffer.close();
        Buffer.close();
      }
    """

    let execution = runFailingNativeFeatureSource(
      source,
      "storage_class_owned_double_release"
    )
    check execution.exitCode != 0
    check "Eido storage access after release" in execution.output

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
