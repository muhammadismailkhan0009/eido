import std/unittest
import support/compiler_test_support

suite "Identifier expression semantics":
  test "rejects an unknown local":
    # Given
    let source = """
      function main() returns Int {
        var value = missing + 1;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
