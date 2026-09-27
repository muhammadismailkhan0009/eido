import std/unittest
import types/model
import support/compiler_test_support

suite "Boolean operator semantics":
  test "not and and or accept Bool operands and return Bool":
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
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etBool
    check program.functions[1].result.typ == etBool
    check program.functions[2].result.typ == etBool
    check program.functions[3].result.typ == etBool

  test "not accepts the Bool result of a comparison":
    # Given
    let source = "function main() returns Bool { return not 1 < 2; }"

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etBool

  test "not rejects a non-Bool operand":
    # Given
    let source = "function main() returns Bool { return not 1; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "and and or reject non-Bool operands":
    # Given
    let andSource = "function main() returns Bool { return true and 1; }"
    let orSource = "function main() returns Bool { return 1 or false; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(andSource)
    expect ValueError:
      discard analyzeSource(orSource)
