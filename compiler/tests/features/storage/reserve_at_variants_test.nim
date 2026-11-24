import std/[strutils, unittest]
import support/feature_test_support

import support/feature_batch_support

suite "Storage explicit placement":
  test "successful native Storage scenarios (batched)":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(
        name: "reserveAt places typed data within native backing without another allocation",
        source: """
      function main() returns Int {
        var backing = Storage<Byte>.allocateRaw(1, 128);
        var address = Alignment.alignUp(Storage<Byte>.address(backing), 8);
        var placed = Storage<Int>.reserveAt(backing, address, 3);
        Storage<Int>.write(placed, 2, 73);
        var seen = Storage<Int>.read(placed, 2);
        Storage<Int>.release(placed);
        var view = Storage<Int>.viewAt(
            backing, address - Storage<Byte>.address(backing) + 16
        );
        var afterRelease = Storage<Int>.read(view, 0);
        Storage<Byte>.release(backing);
        return seen + afterRelease;
      }
    """,
        expected: "146"
      ),
      NativeFeatureCase(
        name: "release of a placed region does not free backing",
        source: """
      function main() returns Int {
        var backing = Storage<Byte>.allocateRaw(1, 64);
        var at = Alignment.alignUp(Storage<Byte>.address(backing), 8);
        var placed = Storage<Int>.reserveAt(backing, at, 1);
        Storage<Int>.write(placed, 0, 33);
        Storage<Int>.release(placed);
        var again = Storage<Int>.reserveAt(backing, at, 1);
        var value = Storage<Int>.read(again, 0);
        Storage<Int>.release(again);
        Storage<Byte>.release(backing);
        return value;
      }
    """,
        expected: "33"
      ),
      NativeFeatureCase(
        name: "borrowed SRAM-style regions support explicit placement without native allocation",
        source: """
      function main() returns Int {
        // Simulate the hardware-provided SRAM address using valid host memory.
        var ownedByPlatform = Storage<Byte>.allocateRaw(1, 128);
        var address = Storage<Byte>.address(ownedByPlatform);
        var sram = Storage<Byte>.borrowAddress(address, 1, 128);
        var placement = Alignment.alignUp(address, Storage<Int>.alignment());
        var users = Storage<Int>.reserveAt(sram, placement, 2);
        Storage<Int>.write(users, 1, 87);
        var resultValue = Storage<Int>.read(users, 1);
        Storage<Int>.release(users);
        Storage<Byte>.release(ownedByPlatform);
        return resultValue;
      }
    """,
        expected: "87"
      ),
      NativeFeatureCase(
        name: "Alignment performs pure arithmetic",
        source: """
      function main() returns Int {
        var next = Alignment.alignUp(19, 16);
        var padding = Alignment.padding(19, 16);
        if (not Alignment.isAligned(next, 16)) { return 0; }
        return next + padding + Alignment.alignDown(31, 16);
      }
    """,
        expected: "61"
      ),
      NativeFeatureCase(
        name: "Alignment observes address limits without overflowing",
        source: """
      function main() returns Int {
        var maximum = 9223372036854775807;
        if (Alignment.alignUp(maximum, 1) != maximum) { return 0; }
        if (Alignment.alignUp(maximum - 7, 8) != maximum - 7) { return 0; }
        if (Alignment.isAligned(maximum, 8)) { return 0; }
        return Alignment.padding(maximum, 8);
      }
    """,
        expected: "1"
      ),
      NativeFeatureCase(
        name: "empty typed and raw allocations have no backing and can be released",
        source: """
      function main() returns Int {
        var typed = Storage<Int>.allocate(0);
        var raw = Storage<Byte>.allocateRaw(0, 8);
        var sum = Storage<Int>.capacity(typed) + Storage<Int>.address(typed)
            + Storage<Byte>.capacity(raw) + Storage<Byte>.address(raw);
        Storage<Int>.release(typed);
        Storage<Byte>.release(raw);
        set typed = Storage<Int>.allocate(2);
        Storage<Int>.write(typed, 1, 42);
        var value = Storage<Int>.read(typed, 1);
        Storage<Int>.release(typed);
        return sum + value;
      }
    """,
        expected: "42"
      )
    ], "reserve_at_variants_test")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "reserveAt rejects memory outside backing region":
    let source = """
      function main() {
        var backing = Storage<Byte>.allocateRaw(1, 24);
        var placed = Storage<Int>.reserveAt(
            backing, Storage<Byte>.address(backing), 4
        );
      }
    """
    let execution = runFailingNativeFeatureSource(source, "storage_reserve_outside")
    check execution.exitCode != 0
    check "outside backing region" in execution.output

  test "reserveAt rejects a misaligned address":
    let source = """
      function main() {
        var backing = Storage<Byte>.allocateRaw(1, 64);
        var badAddress = Storage<Byte>.address(backing) + 1;
        var placed = Storage<Int>.reserveAt(backing, badAddress, 1);
      }
    """
    let execution = runFailingNativeFeatureSource(source, "storage_reserve_misaligned")
    check execution.exitCode != 0
    check "require contract failed" in execution.output


  test "borrowAddress rejects a nonempty null native region":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.borrowAddress(0, 1, 8);
        return Storage<Byte>.capacity(raw);
      }
    """
    let execution = runFailingNativeFeatureSource(source, "storage_borrow_null")
    check execution.exitCode != 0
    check "nonempty native Storage cannot use a nil address" in execution.output
