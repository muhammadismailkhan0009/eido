import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Local initialization forms":
  test "literal initialization: new local can start from a literal":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        return value;
      }
    """

    # When
    let output = runFeatureSource(source, "variable_literal_init")

    # Then
    check output == "5"
  test "computed initialization: new local can read existing locals inside an expression":
    # Given
    let source = """
      function main() returns Int {
        var base = 5;
        var total = base + 2;
        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "variable_computed_init")

    # Then
    check output == "7"
  test "bare identifier initialization is rejected":
    # Given
    let source = """
      function main() returns Int {
        var first = 5;
        var second = first;
        return second;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Local reassignment forms":
  test "literal reassignment: existing local can receive a new literal":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        value = 9;
        return value;
      }
    """

    # When
    let output = runFeatureSource(source, "variable_literal_reassign")

    # Then
    check output == "9"
  test "computed reassignment: existing local can use its current value":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        value = value + 2;
        return value;
      }
    """

    # When
    let output = runFeatureSource(source, "variable_computed_reassign")

    # Then
    check output == "7"
  test "identifier reassignment: existing primitive local can receive another local":
    # Given
    let source = """
      function main() returns Int {
        var first = 5;
        var second = 9;
        second = first;
        return second;
      }
    """

    # When
    let output = runFeatureSource(source, "variable_identifier_reassign")

    # Then
    check output == "5"

suite "Local declaration ordering":
  test "use before declaration is rejected":
    # Given
    let source = """
      function main() returns Int {
        var total = later + 1;
        var later = 5;
        return total;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Local declaration uniqueness":
  test "duplicate local declaration is rejected":
    # Given
    let source = """
      function main() returns Int {
        var value = 1;
        var value = 2;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
