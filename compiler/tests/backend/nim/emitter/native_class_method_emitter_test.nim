import std/[strutils, unittest]
import support/compiler_test_support

suite "Native class method emission":
  test "imports native support and calls class-scoped native ABI symbol":
    # Given
    let source = """
      class Console {
        native function writeLine(String value);
      }

      function main() {
        Console.writeLine("hello");
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "import eido_native" in generated
    check "eido_native_method_Console_writeLine(" in generated
    check "proc eido_method_0_Console_writeLine" notin generated
