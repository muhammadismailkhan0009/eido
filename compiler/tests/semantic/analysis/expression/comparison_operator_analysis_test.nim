import std/unittest
import types/model
import support/compiler_test_support

suite "Equality comparison semantics":
  test "returns Bool for matching primitive operands":
    # Given
    let source = """
      function boolEq(Bool a, Bool b) returns Bool { return a == b; }
      function byteEq(Byte a, Byte b) returns Bool { return a != b; }
      function shortEq(Short a, Short b) returns Bool { return a == b; }
      function intEq(Int a, Int b) returns Bool { return a != b; }
      function floatEq(Float a, Float b) returns Bool { return a == b; }
      function charEq(Char a, Char b) returns Bool { return a != b; }
      function main() returns Bool { return boolEq(true, true); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    for index in 0 .. 5:
      check program.functions[index].result.typ == etBool

  test "compares String operands by equality but does not order them":
    let equalitySource = """
      function same(String left, String right) returns Bool { return left == right; }
      function main() returns Bool { return same("Eido", "Eido"); }
    """
    let orderingSource = "function main() returns Bool { return \"a\" < \"b\"; }"

    let program = analyzeSource(equalitySource)
    check program.functions[0].result.typ == etBool
    expect ValueError:
      discard analyzeSource(orderingSource)

  test "contextually types Byte and Short integer literals":
    # Given
    let source = """
      function byteEq(Byte value) returns Bool { return value == 127; }
      function shortEq(Short value) returns Bool { return 300 == value; }
      function main() returns Bool { return byteEq(127) == shortEq(300); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etBool
    check program.functions[1].result.typ == etBool

  test "rejects mismatched primitive operand types":
    # Given
    let source = "function main() returns Bool { return 1 == 1.0; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Ordered comparison semantics":
  test "returns Bool for matching numeric operands":
    # Given
    let source = """
      function byteLt(Byte a, Byte b) returns Bool { return a < b; }
      function shortLe(Short a, Short b) returns Bool { return a <= b; }
      function intGt(Int a, Int b) returns Bool { return a > b; }
      function floatGe(Float a, Float b) returns Bool { return a >= b; }
      function main() returns Bool { return intGt(2, 1); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    for index in 0 .. 3:
      check program.functions[index].result.typ == etBool

  test "contextually types integral literals from the other operand":
    # Given
    let source = """
      function below(Byte value) returns Bool { return value < 100; }
      function above(Short value) returns Bool { return 100 < value; }
      function main() returns Bool { return below(10) == above(200); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etBool
    check program.functions[1].result.typ == etBool

  test "rejects Bool and Char ordering":
    # Given
    let boolSource = "function main() returns Bool { return false < true; }"
    let charSource = "function main() returns Bool { return 'A' < 'B'; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(boolSource)
    expect ValueError:
      discard analyzeSource(charSource)

  test "rejects cross-type numeric ordering":
    # Given
    let source = "function main() returns Bool { return 1 < 2.0; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
