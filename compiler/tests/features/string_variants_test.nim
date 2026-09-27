import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "String values":
  test "String literal can be returned from main":
    # Given
    let source = """
      function main() returns String {
        return "Eido";
      }
    """

    # When
    let output = runFeatureSource(source, "string_literal")

    # Then
    check output == "Eido"

  test "String parameters and results preserve text":
    let source = """
      function identity(String value) returns String { return value; }
      function main() returns String { return identity("Grüße"); }
    """

    check runFeatureSource(source, "string_signature") == "Grüße"
  test "plus concatenates String values":
    let source = """
      function join(String left, String right) returns String {
        return left + right;
      }
      function main() returns String { return join("Ei", "do"); }
    """

    check runFeatureSource(source, "string_concat") == "Eido"

  test "String equality compares text content":
    let source = """
      function same(String left, String right) returns Bool {
        return left == right;
      }
      function main() returns Bool { return same("Eido", "Eido"); }
    """

    check runFeatureSource(source, "string_equality") == "true"

  test "String inequality compares text content":
    let source = """
      function main() returns Bool { return "Eido" != "Other"; }
    """

    check runFeatureSource(source, "string_inequality") == "true"

suite "String storage in language constructs":
  test "String may be stored in a class field":
    let source = """
      class User { String name; }
      function main() returns String {
        var name = "Alice";
        var user = User { name: name; };
        return user.name;
      }
    """

    check runFeatureSource(source, "string_class_field") == "Alice"

  test "set replaces a String local with a new value":
    let source = """
      function main() returns String {
        var name = "Alice";
        set name = "Bob";
        return name;
      }
    """

    check runFeatureSource(source, "string_set_local") == "Bob"

  test "class-owned method may replace its String field":
    let source = """
      class User {
        String name;
        function rename(String value) { set self.name = value; }
      }
      function main() returns String {
        var user = User { name: "Alice"; };
        user.rename("Bob");
        return user.name;
      }
    """

    check runFeatureSource(source, "string_set_field") == "Bob"

  test "copying a class keeps String values safe under later replacement":
    let source = """
      class User {
        String name;
        function rename(String value) { set self.name = value; }
      }
      function main() returns String {
        var user = User { name: "Alice"; };
        var detached = copy user;
        detached.rename("Bob");
        return user.name + ":" + detached.name;
      }
    """

    check runFeatureSource(source, "string_class_copy") == "Alice:Bob"

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
