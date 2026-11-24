import std/unittest
import support/[compiler_test_support, feature_batch_support]

suite "Equality comparison":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "matching Int values compare equal",
        source: "function main() returns Bool { return 10 == 10; }",
        expected: "true"
      ),
      FeatureBatchCase(
        name: "different Bool values compare not equal",
        source: "function main() returns Bool { return true != false; }",
        expected: "true"
      ),
      FeatureBatchCase(
        name: "matching Char values compare equal",
        source: "function main() returns Bool { return 'A' == 'A'; }",
        expected: "true"
      )
    ], "comparison_variants_test_1")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "Ordered numeric comparison":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "Byte supports less-than with contextual literal typing",
        source: """
      function below(Byte value) returns Bool { return value < 10; }
      function main() returns Bool { return below(7); }
    """,
        expected: "true"
      ),
      FeatureBatchCase(
        name: "Short supports less-than-or-equal",
        source: """
      function atMost(Short a, Short b) returns Bool { return a <= b; }
      function main() returns Bool { return atMost(300, 300); }
    """,
        expected: "true"
      ),
      FeatureBatchCase(
        name: "Int supports greater-than",
        source: "function main() returns Bool { return 10 > 3; }",
        expected: "true"
      ),
      FeatureBatchCase(
        name: "Float supports greater-than-or-equal",
        source: "function main() returns Bool { return 2.5 >= 2.5; }",
        expected: "true"
      )
    ], "comparison_variants_test_2")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

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
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "arithmetic binds before ordered comparison",
        source: "function main() returns Bool { return 1 + 2 < 4 * 2; }",
        expected: "true"
      ),
      FeatureBatchCase(
        name: "ordered comparison binds before equality",
        source: "function main() returns Bool { return 1 < 2 == true; }",
        expected: "true"
      )
    ], "comparison_variants_test_3")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected
