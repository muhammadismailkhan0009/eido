import std/[strutils, unittest]
import support/compiler_test_support

suite "Boolean operator emission":
  test "emits Nim short-circuit boolean operators":
    # Given
    let source = """
      function negate(Bool value) returns Bool { return not value; }
      function both(Bool a, Bool b) returns Bool { return a and b; }
      function either(Bool a, Bool b) returns Bool { return a or b; }
      function main() returns Bool {
        return negate(false) and either(true, false);
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "return (not eido_local_0_value)" in generated
    check "return (eido_local_0_a and eido_local_1_b)" in generated
    check "return (eido_local_0_a or eido_local_1_b)" in generated
