import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Unary numeric negation":
  test "negative Int literal":
    # Given
    let source = "function main() returns Int { return -5; }"

    # When
    let output = runFeatureSource(source, "expression_negative_int")

    # Then
    check output == "-5"
  test "negative Float literal":
    # Given
    let source = "function main() returns Float { return -2.5; }"

    # When
    let output = runFeatureSource(source, "expression_negative_float")

    # Then
    check output == "-2.5"
  test "negates an Int variable":
    # Given
    let source = """
      function negate(Int value) returns Int {
        return -value;
      }

      function main() returns Int {
        return negate(7);
      }
    """

    # When
    let output = runFeatureSource(source, "expression_negate_variable")

    # Then
    check output == "-7"

  test "negates a function call result":
    # Given
    let source = """
      function value() returns Int { return 7; }
      function main() returns Int { return -value(); }
    """

    # When
    let output = runFeatureSource(source, "expression_negate_call")

    # Then
    check output == "-7"

  test "negates a grouped expression":
    # Given
    let source = "function main() returns Int { return -(10 + 5); }"

    # When
    let output = runFeatureSource(source, "expression_negate_group")

    # Then
    check output == "-15"

  test "double negation returns the original numeric value":
    # Given
    let source = "function main() returns Int { return --5; }"

    # When
    let output = runFeatureSource(source, "expression_double_negation")

    # Then
    check output == "5"

suite "Unary negation type restrictions":
  test "Byte operand is rejected":
    # Given
    let source = """
      function negate(Byte value) returns Byte { return -value; }
      function main() returns Int { return 0; }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "Short operand is rejected":
    # Given
    let source = """
      function negate(Short value) returns Short { return -value; }
      function main() returns Int { return 0; }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "Bool operand is rejected":
    # Given
    let source = "function main() returns Bool { return -true; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "Char operand is rejected":
    # Given
    let source = "function main() returns Char { return -'A'; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Unary negation binding":
  test "unary minus binds before multiplication":
    # Given
    let source = "function main() returns Int { return -2 * 3; }"

    # When
    let output = runFeatureSource(source, "expression_negation_binding")

    # Then
    check output == "-6"

  test "subtraction can be followed by unary minus":
    # Given
    let source = "function main() returns Int { return 10 - -5; }"

    # When
    let output = runFeatureSource(source, "expression_subtract_negative")

    # Then
    check output == "15"
