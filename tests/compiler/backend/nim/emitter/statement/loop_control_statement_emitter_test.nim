import std/[strutils, unittest]
import support/compiler_test_support

suite "Loop control statement emission":
  test "emits break and continue inside a while body":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        while (count < 3) {
          set count = count + 1;
          if (count == 1) {
            continue;
          }
          break;
        }
        return count;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "continue\n" in generated
    check "break\n" in generated
