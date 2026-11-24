import std/unittest
import support/[compiler_test_support, feature_test_support]

import support/feature_batch_support

suite "String values":
  test "native cases group 1":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "String literal can be returned from main", source: """
      function main() returns String {
        return "Eido";
      }
    """, expected: "Eido"),
      NativeFeatureCase(name: "String parameters and results preserve text", source: """
      function identity(String value) returns String { return value; }
      function main() returns String { return identity("Grüße"); }
    """, expected: "Grüße"),
      NativeFeatureCase(name: "plus concatenates String values", source: """
      function join(String left, String right) returns String {
        return left + right;
      }
      function main() returns String { return join("Ei", "do"); }
    """, expected: "Eido"),
    ], "string_values_1")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "native cases group 2":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "String equality compares text content", source: """
      function same(String left, String right) returns Bool {
        return left == right;
      }
      function main() returns Bool { return same("Eido", "Eido"); }
    """, expected: "true"),
      NativeFeatureCase(name: "String inequality compares text content", source: """
      function main() returns Bool { return "Eido" != "Other"; }
    """, expected: "true"),
    ], "string_values_2")
    check results.len == 2
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "String storage in language constructs":
  test "native cases group 1":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "String may be stored in a class field", source: """
      class User { String name; }
      function main() returns String {
        var name = "Alice";
        var user = User { name = name; };
        return user.name;
      }
    """, expected: "Alice"),
      NativeFeatureCase(name: "set replaces a String local with a new value", source: """
      function main() returns String {
        var name = "Alice";
        set name = "Bob";
        return name;
      }
    """, expected: "Bob"),
      NativeFeatureCase(name: "class-owned method may replace its String field", source: """
      class User {
        String name;
        function rename(String value) { set self.name = value; }
      }
      function main() returns String {
        var user = User { name = "Alice"; };
        user.rename("Bob");
        return user.name;
      }
    """, expected: "Bob"),
    ], "string_storage_in_language_constructs_1")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "native cases group 2":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "copying a class keeps String values safe under later replacement", source: """
      class User {
        String name;
        function rename(String value) { set self.name = value; }
      }
      function main() returns String {
        var user = User { name = "Alice"; };
        var detached = copy user;
        detached.rename("Bob");
        return user.name + ":" + detached.name;
      }
    """, expected: "Alice:Bob"),
    ], "string_storage_in_language_constructs_2")
    check results.len == 1
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "String binding boundaries":
  test "bare existing String cannot create another local binding":
    let source = """
      function main() returns String {
        var first = "Eido";
        var second = first;
        return second;
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "copy and ref remain class-only operations":
    let copied = """
      function main() returns String {
        var value = "Eido";
        var second = copy value;
        return second;
      }
    """
    let aliased = """
      function main() returns String {
        var value = "Eido";
        var second = ref value;
        return second;
      }
    """
    expect ValueError:
      discard analyzeSource(copied)
    expect ValueError:
      discard analyzeSource(aliased)
