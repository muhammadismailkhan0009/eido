import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Binary arithmetic operations":
  test "Int addition":
    # Given
    let source = "function main() returns Int { return 10 + 5; }"

    # When
    let output = runFeatureSource(source, "expression_add")

    # Then
    check output == "15"
  test "Int subtraction":
    # Given
    let source = "function main() returns Int { return 10 - 3; }"

    # When
    let output = runFeatureSource(source, "expression_subtract")

    # Then
    check output == "7"
  test "Int multiplication":
    # Given
    let source = "function main() returns Int { return 6 * 7; }"

    # When
    let output = runFeatureSource(source, "expression_multiply")

    # Then
    check output == "42"
  test "Int division":
    # Given
    let source = "function main() returns Int { return 10 / 3; }"

    # When
    let output = runFeatureSource(source, "expression_int_divide")

    # Then
    check output == "3"
  test "Float addition":
    # Given
    let source = "function main() returns Float { return 1.5 + 2.5; }"

    # When
    let output = runFeatureSource(source, "expression_float_add")

    # Then
    check output == "4.0"
  test "Float division":
    # Given
    let source = "function main() returns Float { return 5.0 / 2.0; }"

    # When
    let output = runFeatureSource(source, "expression_float_divide")

    # Then
    check output == "2.5"

suite "Binary operator precedence":
  test "multiplication has higher precedence than addition":
    # Given
    let source = "function main() returns Int { return 10 + 20 * 3; }"

    # When
    let output = runFeatureSource(source, "expression_precedence")

    # Then
    check output == "70"
  test "division has higher precedence than addition":
    # Given
    let source = "function main() returns Int { return 10 + 20 / 5; }"

    # When
    let output = runFeatureSource(source, "expression_div_before_add")

    # Then
    check output == "14"
  test "multiplication has higher precedence than subtraction":
    # Given
    let source = "function main() returns Int { return 20 - 3 * 4; }"

    # When
    let output = runFeatureSource(source, "expression_mul_before_sub")

    # Then
    check output == "8"

suite "Equal-precedence binary associativity":
  test "multiplication and division are evaluated left to right":
    # Given
    let source = "function main() returns Int { return 20 / 5 * 2; }"

    # When
    let output = runFeatureSource(source, "expression_mul_div_left_to_right")

    # Then
    check output == "8"
  test "addition and subtraction are evaluated left to right":
    # Given
    let source = "function main() returns Int { return 10 - 3 + 2; }"

    # When
    let output = runFeatureSource(source, "expression_add_sub_left_to_right")

    # Then
    check output == "9"

suite "Grouping delimiter equivalence":
  test "parentheses override normal precedence":
    # Given
    let source = "function main() returns Int { return (10 + 20) * 3; }"

    # When
    let output = runFeatureSource(source, "expression_parentheses")

    # Then
    check output == "90"
  test "square brackets override normal precedence":
    # Given
    let source = "function main() returns Int { return [10 + 20] * 3; }"

    # When
    let output = runFeatureSource(source, "expression_square_group")

    # Then
    check output == "90"
  test "curly brackets override normal precedence":
    # Given
    let source = "function main() returns Int { return {10 + 20} * 3; }"

    # When
    let output = runFeatureSource(source, "expression_curly_group")

    # Then
    check output == "90"
  test "all three grouping delimiters can be nested":
    # Given
    let source =
      "function main() returns Int { return [{(10 + 20) * 2} + 5] * 2; }"

    # When
    let output = runFeatureSource(source, "expression_nested_groups")

    # Then
    check output == "130"
  test "grouping delimiters do not have separate precedence levels":
    # Given
    let source =
      "function main() returns Int { return {2 + [3 * (4 + 1)]}; }"

    # When
    let output = runFeatureSource(source, "expression_group_equivalence")

    # Then
    check output == "17"

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

suite "Boolean word operators":
  test "not negates Bool":
    # Given
    let source = "function main() returns Bool { return not false; }"

    # When
    let output = runFeatureSource(source, "boolean_not")

    # Then
    check output == "true"

  test "and combines Bool operands":
    # Given
    let source = "function main() returns Bool { return true and false; }"

    # When
    let output = runFeatureSource(source, "boolean_and")

    # Then
    check output == "false"

  test "or combines Bool operands":
    # Given
    let source = "function main() returns Bool { return false or true; }"

    # When
    let output = runFeatureSource(source, "boolean_or")

    # Then
    check output == "true"

suite "Boolean operator precedence":
  test "comparison binds inside not":
    # Given
    let source = "function main() returns Bool { return not 1 < 2; }"

    # When
    let output = runFeatureSource(source, "boolean_not_comparison")

    # Then
    check output == "false"

  test "and binds before or":
    # Given
    let source = "function main() returns Bool { return true or false and false; }"

    # When
    let output = runFeatureSource(source, "boolean_and_before_or")

    # Then
    check output == "true"

suite "Boolean short circuiting":
  test "false and skips the right operand":
    # Given
    let source =
      "function main() returns Bool { return false and 1 / 0 == 0; }"

    # When
    let output = runFeatureSource(source, "boolean_and_short_circuit")

    # Then
    check output == "false"

  test "true or skips the right operand":
    # Given
    let source =
      "function main() returns Bool { return true or 1 / 0 == 0; }"

    # When
    let output = runFeatureSource(source, "boolean_or_short_circuit")

    # Then
    check output == "true"

suite "Boolean symbol exclusion":
  test "symbolic boolean operators remain unsupported":
    # Given
    let notSource = "function main() returns Bool { return !true; }"
    let andSource = "function main() returns Bool { return true && false; }"
    let orSource = "function main() returns Bool { return true || false; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(notSource)
    expect ValueError:
      discard analyzeSource(andSource)
    expect ValueError:
      discard analyzeSource(orSource)
