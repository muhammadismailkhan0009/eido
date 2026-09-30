import std/[os, strutils, unittest]
import support/feature_test_support

const ArenaSource = staticRead(
  currentSourcePath().parentDir / "../../../../stdlib/src/arena.eido"
)

suite "Arena memory policy":
  test "generic arena allocates slices sequentially and resets in bulk":
    let source = ArenaSource & """
      function main() returns Int {
        var arena = Arena<Int>.create(8);
        var first = arena.allocate(3);
        Storage<Int>.write(first, 0, 4);
        Storage<Int>.write(first, 2, 6);

        var second = arena.allocate(2);
        Storage<Int>.write(second, 0, 5);
        var remainingBeforeReset = arena.remaining();
        var beforeReset =
          Storage<Int>.read(first, 0) +
          Storage<Int>.read(second, 0) +
          remainingBeforeReset;

        arena.reset();
        var remainingAfterReset = arena.remaining();
        var reused = arena.allocate(1);
        Storage<Int>.write(reused, 0, 11);
        var resultValue =
          beforeReset +
          Storage<Int>.read(reused, 0) +
          remainingAfterReset;
        arena.release();
        return resultValue;
      }
    """

    check runNativeFeatureSource(source, "arena_int_policy") == "31"

  test "same Arena<T> implementation supports String storage":
    let source = ArenaSource & """
      function main() returns String {
        var arena = Arena<String>.create(2);
        var values = arena.allocate(1);
        Storage<String>.write(values, 0, "arena");
        var resultValue = Storage<String>.read(values, 0);
        arena.release();
        return resultValue;
      }
    """

    check runNativeFeatureSource(source, "arena_string_policy") == "arena"

  test "arena allocations remain borrowed and cannot release backing":
    let source = ArenaSource & """
      function main() {
        var arena = Arena<Int>.create(2);
        var allocation = arena.allocate(1);
        Storage<Int>.release(allocation);
      }
    """

    expect ValueError:
      discard runNativeFeatureSource(source, "arena_borrowed_release")

  test "arena rejects allocation beyond remaining capacity":
    let source = ArenaSource & """
      function main() {
        var arena = Arena<Int>.create(2);
        var allocation = arena.allocate(3);
      }
    """

    let execution = runFailingNativeFeatureSource(
      source,
      "arena_capacity_contract"
    )
    check execution.exitCode != 0
    check "require contract failed" in execution.output
