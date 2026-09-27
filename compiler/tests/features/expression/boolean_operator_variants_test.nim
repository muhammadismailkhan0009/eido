import std/unittest
import support/[compiler_test_support, feature_test_support]

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
