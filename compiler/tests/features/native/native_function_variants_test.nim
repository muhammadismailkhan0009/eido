import std/unittest
import support/feature_test_support

suite "Native function execution":
  test "calls the bundled native support module from Eido":
    # Given
    let source = """
      native function platformWriteLine(String value);
      function main() { platformWriteLine("native-ok"); }
    """

    # When
    let output = runFeatureSource(source, "native_write_line")

    # Then
    check output == "native-ok"
