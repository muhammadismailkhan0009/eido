import std/unittest
import compiler/frontend/ast/expressions
import support/compiler_test_support

suite "Comparison operator parsing":
  test "binds arithmetic before ordered comparison":
    # Given
    let source = "function main() returns Bool { return 1 + 2 < 4 * 2; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boLess
    check expression.left.op == boAdd
    check expression.right.op == boMultiply

  test "binds ordered comparison before equality":
    # Given
    let source = "function main() returns Bool { return 1 < 2 == true; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boEqual
    check expression.left.kind == ekBinary
    check expression.left.op == boLess
