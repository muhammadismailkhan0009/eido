import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "While execution":
  test "repeats while the condition remains true":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        while (count < 5) {
          set count = count + 1;
        }
        return count;
      }
    """

    # When
    let output = runFeatureSource(source, "while_repetition")

    # Then
    check output == "5"

  test "skips the body when the initial condition is false":
    # Given
    let source = """
      function main() returns Int {
        var value = 7;
        while (false) {
          set value = 9;
        }
        return value;
      }
    """

    # When
    let output = runFeatureSource(source, "while_initial_false")

    # Then
    check output == "7"

  test "supports an empty body when the condition is false":
    # Given
    let source = """
      function main() returns Int {
        while (false) {
        }
        return 3;
      }
    """

    # When
    let output = runFeatureSource(source, "while_empty_body")

    # Then
    check output == "3"

suite "While nesting":
  test "nested loops compose":
    # Given
    let source = """
      function main() returns Int {
        var outer = 0;
        var total = 0;

        while (outer < 2) {
          var inner = 0;
          while (inner < 3) {
            set total = total + 1;
            set inner = inner + 1;
          }
          set outer = outer + 1;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "nested_while")

    # Then
    check output == "6"

suite "While condition rules":
  test "Bool expression condition is accepted":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        while (count < 3 and true) {
          set count = count + 1;
        }
        return count;
      }
    """

    # When
    let output = runFeatureSource(source, "while_bool_condition")

    # Then
    check output == "3"

  test "non-Bool condition is rejected":
    # Given
    let source = """
      function main() returns Int {
        while (1) {
          return 1;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "unparenthesized condition is rejected":
    # Given
    let source = """
      function main() returns Int {
        while true {
          return 1;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "While scope and return coverage":
  test "loop-local declaration is unavailable after the loop":
    # Given
    let source = """
      function main() returns Int {
        while (false) {
          var inside = 1;
        }
        return inside;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "while alone does not satisfy a result function return":
    # Given
    let source = """
      function value() returns Int {
        while (true) {
          return 1;
        }
      }

      function main() returns Int {
        return value();
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
