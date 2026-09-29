import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Else if chains":
  test "else if branch executes when earlier condition is false":
    # Given
    let source = """
      function classify(Int value) returns Int {
        if (value < 0) {
          return -1;
        } else if (value == 0) {
          return 0;
        } else {
          return 1;
        }
      }

      function main() returns Int {
        return classify(0);
      }
    """

    # When
    let output = runFeatureSource(source, "else_if_branch")

    # Then
    check output == "0"

  test "later else if branch executes in a chain":
    # Given
    let source = """
      function classify(Int value) returns Int {
        if (value < 0) {
          return -1;
        } else if (value == 0) {
          return 0;
        } else if (value < 10) {
          return 1;
        } else {
          return 2;
        }
      }

      function main() returns Int {
        return classify(5);
      }
    """

    # When
    let output = runFeatureSource(source, "else_if_chain")

    # Then
    check output == "1"

  test "final else executes when no else if condition matches":
    # Given
    let source = """
      function classify(Int value) returns Int {
        if (value < 0) {
          return -1;
        } else if (value == 0) {
          return 0;
        } else {
          return 2;
        }
      }

      function main() returns Int {
        return classify(20);
      }
    """

    # When
    let output = runFeatureSource(source, "else_if_final_else")

    # Then
    check output == "2"

  test "else if chain may fall through when there is no final else":
    # Given
    let source = """
      function main() returns Int {
        var outcome = 7;
        if (false) {
          set outcome = 1;
        } else if (false) {
          set outcome = 2;
        }
        return outcome;
      }
    """

    # When
    let output = runFeatureSource(source, "else_if_fallthrough")

    # Then
    check output == "7"

  test "unparenthesized else if condition is rejected":
    # Given
    let source = """
      function main() returns Int {
        if (false) {
          return 0;
        } else if true {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
