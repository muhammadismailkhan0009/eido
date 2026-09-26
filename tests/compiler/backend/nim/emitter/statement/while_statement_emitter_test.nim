import std/[strutils, unittest]
import support/compiler_test_support

suite "While statement emission":
  test "emits while with recursively indented body statements":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        while (count < 3) {
          set count = count + 1;
        }
        return count;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "while (eido_local_0_count < int64(3)):\n    eido_local_0_count = (eido_local_0_count + int64(1))" in generated
