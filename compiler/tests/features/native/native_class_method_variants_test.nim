import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Native class method execution":
  test "calls bundled native support directly through class API":
    # Given
    let source = """
      class Console {
        native function writeLine(String value);
      }

      function main() {
        Console.writeLine("native-class-ok");
      }
    """

    # When
    let output = runFeatureSource(source, "native_class_write_line")

    # Then
    check output == "native-class-ok"

  test "rejects calling a native static method through an instance":
    # Given
    let source = """
      class Console {
        native function writeLine(String value);
      }

      function main() {
        var console = Console {};
        console.writeLine("invalid");
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
