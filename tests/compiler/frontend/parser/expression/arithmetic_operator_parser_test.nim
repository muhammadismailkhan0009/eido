import std/unittest
import compiler/frontend/ast/expressions
import support/compiler_test_support

suite "Arithmetic operator parsing":
  test "binds multiplication before addition":
    # Given
    let source = "function main() returns Int { return 10 + 20 * 3; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boAdd
    check expression.right.kind == ekBinary
    check expression.right.op == boMultiply
