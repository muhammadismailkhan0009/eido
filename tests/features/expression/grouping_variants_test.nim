import std/unittest
import support/feature_test_support

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
