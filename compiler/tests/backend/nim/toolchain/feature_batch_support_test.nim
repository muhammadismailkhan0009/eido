import std/[unittest]
import support/feature_batch_support

suite "Feature batch runner":
  test "independent Eido programs run in the same native executable":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(
        name: "first arithmetic program",
        source: "function main() returns Int { return 14 + 7; }",
        expected: "21"
      ),
      NativeFeatureCase(
        name: "second arithmetic program",
        source: "function main() returns Int { return 6 * 7; }",
        expected: "42"
      ),
      NativeFeatureCase(
        name: "byte storage allocation",
        source: """
          function main() returns Int {
            var raw = Storage<Byte>.allocateRaw(1, 8);
            var typed = Storage<Int>.view(raw, 0);
            Storage<Int>.write(typed, 0, 81);
            var value = Storage<Int>.read(typed, 0);
            Storage<Byte>.release(raw);
            return value;
          }
        """,
        expected: "81"
      )
    ], "native_batch_smoke")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "automatic batch handles fixtures requiring native Storage support":
    let results = runFeatureBatch(@[
      FeatureBatchCase(name: "addition", source: "function main() returns Int { return 2 + 3; }", expected: "5"),
      FeatureBatchCase(name: "comparison", source: "function main() returns Bool { return 3 > 2; }", expected: "true")
    ], "vm_batch_smoke")
    check results.len == 2
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected
