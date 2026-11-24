import std/unittest
import support/[compiler_test_support, feature_batch_support]

suite "Unary numeric negation":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "negative Int literal",
        source: "function main() returns Int { return -5; }",
        expected: "-5"
      ),
      FeatureBatchCase(
        name: "negative Float literal",
        source: "function main() returns Float { return -2.5; }",
        expected: "-2.5"
      ),
      FeatureBatchCase(
        name: "negates an Int variable",
        source: """
      function negate(Int value) returns Int {
        return -value;
      }

      function main() returns Int {
        return negate(7);
      }
    """,
        expected: "-7"
      ),
      FeatureBatchCase(
        name: "negates a function call result",
        source: """
      function value() returns Int { return 7; }
      function main() returns Int { return -value(); }
    """,
        expected: "-7"
      ),
      FeatureBatchCase(
        name: "negates a grouped expression",
        source: "function main() returns Int { return -(10 + 5); }",
        expected: "-15"
      ),
      FeatureBatchCase(
        name: "double negation returns the original numeric value",
        source: "function main() returns Int { return --5; }",
        expected: "5"
      )
    ], "unary_negation_variants_test_1")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

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
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "unary minus binds before multiplication",
        source: "function main() returns Int { return -2 * 3; }",
        expected: "-6"
      ),
      FeatureBatchCase(
        name: "subtraction can be followed by unary minus",
        source: "function main() returns Int { return 10 - -5; }",
        expected: "15"
      )
    ], "unary_negation_variants_test_2")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected
