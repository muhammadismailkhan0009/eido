import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Equality comparison":
  test "matching Int values compare equal":
    # Given
    let source = "function main() returns Bool { return 10 == 10; }"

    # When
    let output = runFeatureSource(source, "comparison_int_equal")

    # Then
    check output == "true"

  test "different Bool values compare not equal":
    # Given
    let source = "function main() returns Bool { return true != false; }"

    # When
    let output = runFeatureSource(source, "comparison_bool_not_equal")

    # Then
    check output == "true"

  test "matching Char values compare equal":
    # Given
    let source = "function main() returns Bool { return 'A' == 'A'; }"

    # When
    let output = runFeatureSource(source, "comparison_char_equal")

    # Then
    check output == "true"

suite "Ordered numeric comparison":
  test "Byte supports less-than with contextual literal typing":
    # Given
    let source = """
      function below(Byte value) returns Bool { return value < 10; }
      function main() returns Bool { return below(7); }
    """

    # When
    let output = runFeatureSource(source, "comparison_byte_less")

    # Then
    check output == "true"

  test "Short supports less-than-or-equal":
    # Given
    let source = """
      function atMost(Short a, Short b) returns Bool { return a <= b; }
      function main() returns Bool { return atMost(300, 300); }
    """

    # When
    let output = runFeatureSource(source, "comparison_short_less_equal")

    # Then
    check output == "true"

  test "Int supports greater-than":
    # Given
    let source = "function main() returns Bool { return 10 > 3; }"

    # When
    let output = runFeatureSource(source, "comparison_int_greater")

    # Then
    check output == "true"

  test "Float supports greater-than-or-equal":
    # Given
    let source = "function main() returns Bool { return 2.5 >= 2.5; }"

    # When
    let output = runFeatureSource(source, "comparison_float_greater_equal")

    # Then
    check output == "true"

suite "Comparison type compatibility":
  test "equality rejects different primitive types":
    # Given
    let source = "function main() returns Bool { return 1 == 1.0; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "ordered comparison rejects Bool":
    # Given
    let source = "function main() returns Bool { return false < true; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Comparison binding":
  test "arithmetic binds before ordered comparison":
    # Given
    let source = "function main() returns Bool { return 1 + 2 < 4 * 2; }"

    # When
    let output = runFeatureSource(source, "comparison_arithmetic_binding")

    # Then
    check output == "true"

  test "ordered comparison binds before equality":
    # Given
    let source = "function main() returns Bool { return 1 < 2 == true; }"

    # When
    let output = runFeatureSource(source, "comparison_equality_binding")

    # Then
    check output == "true"
