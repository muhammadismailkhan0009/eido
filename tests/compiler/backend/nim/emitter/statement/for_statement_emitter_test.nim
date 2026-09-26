import std/[strutils, unittest]
import support/compiler_test_support

suite "For statement emission":
  test "lowers for to labeled block and while with update":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;
        for (var i = 0; i < 3; i = i + 1) {
          total = total + i;
        }
        return total;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "block eido_for_break_" in generated
    check "while " in generated
    check "eido_local_1_i = (eido_local_1_i + int64(1))" in generated

  test "lowers for continue through the update path":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;
        for (var i = 0; i < 3; i = i + 1) {
          if (i == 1) {
            continue;
          }
          total = total + i;
        }
        return total;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "block eido_for_continue_" in generated
    check "break eido_for_continue_" in generated
