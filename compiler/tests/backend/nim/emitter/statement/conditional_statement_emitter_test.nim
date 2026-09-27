import std/[strutils, unittest]
import support/compiler_test_support

suite "Conditional statement emission":
  test "emits if else blocks with nested statements":
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
        return choose(true);
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "if eido_local_0_flag:\n    return int64(1)\n  else:\n    return int64(2)" in generated

  test "emits else if as a nested conditional branch":
    # Given
    let source = """
      function choose(Int value) returns Int {
        if (value < 0) {
          return -1;
        } else if (value == 0) {
          return 0;
        } else {
          return 1;
        }
      }

      function main() returns Int {
        return choose(0);
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "else:\n    if " in generated
