import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "For execution":
  test "runs initializer condition body and update":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;

        for (var i = 0; i < 4; i = i + 1) {
          total = total + i;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "for_basic")

    # Then
    check output == "6"

  test "skips body when initial condition is false":
    # Given
    let source = """
      function main() returns Int {
        var total = 7;

        for (var i = 5; i < 5; i = i + 1) {
          total = 9;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "for_initial_false")

    # Then
    check output == "7"

suite "For loop control":
  test "continue still executes the update clause":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;

        for (var i = 0; i < 5; i = i + 1) {
          if (i == 2) {
            continue;
          }

          total = total + i;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "for_continue_update")

    # Then
    check output == "8"

  test "break exits the for loop":
    # Given
    let source = """
      function main() returns Int {
        var result = 0;

        for (var i = 0; i < 10; i = i + 1) {
          if (i == 3) {
            break;
          }

          result = result + 1;
        }

        return result;
      }
    """

    # When
    let output = runFeatureSource(source, "for_break")

    # Then
    check output == "3"

  test "nested for controls target the nearest loop":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;

        for (var outer = 0; outer < 2; outer = outer + 1) {
          for (var inner = 0; inner < 4; inner = inner + 1) {
            if (inner == 1) {
              continue;
            }

            if (inner == 3) {
              break;
            }

            total = total + 1;
          }
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "for_nested_controls")

    # Then
    check output == "4"

suite "For syntax type and scope":
  test "initializer binding does not leak after the loop":
    # Given
    let source = """
      function main() returns Int {
        for (var i = 0; i < 1; i = i + 1) {
        }

        return i;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "non-Bool condition is rejected":
    # Given
    let source = """
      function main() returns Int {
        for (var i = 0; 1; i = i + 1) {
        }

        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "parentheses are mandatory":
    # Given
    let source = """
      function main() returns Int {
        for var i = 0; i < 1; i = i + 1 {
        }

        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
