import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Conditional branch selection":
  test "if executes when condition is true":
    # Given
    let source = """
      function main() returns Int {
        var result = 0;
        if (2 > 1) {
          set result = 7;
        }
        return result;
      }
    """

    # When
    let output = runFeatureSource(source, "if_true_branch")

    # Then
    check output == "7"

  test "if without else falls through when condition is false":
    # Given
    let source = """
      function main() returns Int {
        var result = 3;
        if (false) {
          set result = 9;
        }
        return result;
      }
    """

    # When
    let output = runFeatureSource(source, "if_false_fallthrough")

    # Then
    check output == "3"

  test "else executes when condition is false":
    # Given
    let source = """
      function choose(Bool flag) returns Int {
        if (flag) {
          return 1;
        } else {
          return 2;
        }
      }

      function main() returns Int {
        return choose(false);
      }
    """

    # When
    let output = runFeatureSource(source, "if_else_false_branch")

    # Then
    check output == "2"

suite "Conditional nesting":
  test "nested if statements compose":
    # Given
    let source = """
      function choose(Int value) returns Int {
        if (value > 0) {
          if (value > 10) {
            return 2;
          } else {
            return 1;
          }
        } else {
          return 0;
        }
      }

      function main() returns Int {
        return choose(20);
      }
    """

    # When
    let output = runFeatureSource(source, "nested_if")

    # Then
    check output == "2"

suite "Conditional type and scope rules":
  test "non-Bool condition is rejected":
    # Given
    let source = """
      function main() returns Int {
        if (1) {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "branch-local declaration is unavailable after the branch":
    # Given
    let source = """
      function main() returns Int {
        if (true) {
          var inside = 7;
        }
        return inside;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Conditional return coverage":
  test "result function may end in if else when both branches return":
    # Given
    let source = """
      function choose(Bool flag) returns Int {
        if (flag) {
          return 7;
        } else {
          return 9;
        }
      }

      function main() returns Int {
        return choose(true);
      }
    """

    # When
    let output = runFeatureSource(source, "if_all_paths_return")

    # Then
    check output == "7"

  test "result function rejects a final conditional with a falling-through branch":
    # Given
    let source = """
      function choose(Bool flag) returns Int {
        if (flag) {
          return 7;
        } else {
          var value = 9;
        }
      }

      function main() returns Int {
        return choose(true);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Conditional syntax":
  test "unparenthesized condition is rejected":
    # Given
    let source = """
      function main() returns Int {
        if true {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
