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

  test "automatic batch handles pure VM fixtures":
    let results = runFeatureBatch(@[
      FeatureBatchCase(name: "addition", source: "function main() returns Int { return 2 + 3; }", expected: "5"),
      FeatureBatchCase(name: "comparison", source: "function main() returns Bool { return 3 > 2; }", expected: "true")
    ], "vm_batch_smoke")
    check results.len == 2
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected


  test "native batch cache keys include every generated module":
    let first = NativeFeatureCase(name: "first", source: "function main() returns Int { return 1; }", expected: "1")
    let second = NativeFeatureCase(name: "second", source: "function main() returns Int { return 2; }", expected: "2")
    let changed = NativeFeatureCase(name: "second", source: "function main() returns Int { return 3; }", expected: "3")
    let a = runNativeFeatureBatch(@[first, second], "cache_modules")
    let b = runNativeFeatureBatch(@[first, changed], "cache_modules")
    let c = runNativeFeatureBatch(@[first, second], "cache_modules")
    check a[1].actual == "2"
    check b[1].actual == "3"
    check c[1].actual == "2"
