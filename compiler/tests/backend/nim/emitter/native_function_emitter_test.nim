import std/[strutils, unittest]
import support/compiler_test_support

suite "Native function emission":
  test "imports native support and calls unmangled backend ABI symbol":
    # Given
    let source = """
      native function platformWriteLine(String value);
      function main() { platformWriteLine("hello"); }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "import eido_native" in generated
    check "eido_native_platformWriteLine(" in generated
    check "proc eido_fn_0_platformWriteLine" notin generated
