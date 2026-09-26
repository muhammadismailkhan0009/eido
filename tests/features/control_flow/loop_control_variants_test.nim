import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Break execution":
  test "break exits the nearest while loop early":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;

        while (count < 10) {
          count = count + 1;
          if (count == 3) {
            break;
          }
        }

        return count;
      }
    """

    # When
    let output = runFeatureSource(source, "break_early_exit")

    # Then
    check output == "3"

  test "break in a nested loop exits only that loop":
    # Given
    let source = """
      function main() returns Int {
        var outer = 0;
        var total = 0;

        while (outer < 2) {
          var inner = 0;

          while (inner < 5) {
            inner = inner + 1;
            if (inner == 2) {
              break;
            }
            total = total + 1;
          }

          outer = outer + 1;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "break_nearest_loop")

    # Then
    check output == "2"

suite "Continue execution":
  test "continue skips the rest of the current iteration":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        var total = 0;

        while (count < 5) {
          count = count + 1;

          if (count == 3) {
            continue;
          }

          total = total + count;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "continue_skip_iteration")

    # Then
    check output == "12"

  test "continue in a nested loop advances only that loop":
    # Given
    let source = """
      function main() returns Int {
        var outer = 0;
        var total = 0;

        while (outer < 2) {
          var inner = 0;

          while (inner < 3) {
            inner = inner + 1;

            if (inner == 2) {
              continue;
            }

            total = total + 1;
          }

          outer = outer + 1;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "continue_nearest_loop")

    # Then
    check output == "4"

suite "Loop control context":
  test "break outside a loop is rejected":
    # Given
    let source = """
      function main() returns Int {
        break;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "continue outside a loop is rejected":
    # Given
    let source = """
      function main() returns Int {
        continue;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
