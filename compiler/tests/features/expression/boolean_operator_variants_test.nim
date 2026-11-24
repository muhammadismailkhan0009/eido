import std/unittest
import support/[compiler_test_support, feature_test_support, feature_batch_support]

suite "Boolean word operators":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "not negates Bool",
        source: "function main() returns Bool { return not false; }",
        expected: "true"
      ),
      FeatureBatchCase(
        name: "and combines Bool operands",
        source: "function main() returns Bool { return true and false; }",
        expected: "false"
      ),
      FeatureBatchCase(
        name: "or combines Bool operands",
        source: "function main() returns Bool { return false or true; }",
        expected: "true"
      )
    ], "boolean_operator_variants_test_1")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "Boolean operator precedence":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "comparison binds inside not",
        source: "function main() returns Bool { return not 1 < 2; }",
        expected: "false"
      ),
      FeatureBatchCase(
        name: "and binds before or",
        source: "function main() returns Bool { return true or false and false; }",
        expected: "true"
      )
    ], "boolean_operator_variants_test_2")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

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
