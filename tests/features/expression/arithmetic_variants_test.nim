import std/unittest
import support/feature_test_support

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
