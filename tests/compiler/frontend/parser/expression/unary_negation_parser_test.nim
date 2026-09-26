import std/unittest
import compiler/frontend/ast/expressions
import support/compiler_test_support

suite "Unary numeric negation parsing":
  test "binds unary minus before multiplication":
    # Given
    let source = "function main() returns Int { return -2 * 3; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boMultiply
    check expression.left.kind == ekUnary
    check expression.left.unaryOp == uoNegate

  test "allows unary minus to wrap a grouped expression":
    # Given
    let source = "function main() returns Int { return -(2 + 3); }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekUnary
    check expression.operand.kind == ekBinary

  test "parses repeated unary minus recursively":
    # Given
    let source = "function main() returns Int { return --5; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekUnary
    check expression.operand.kind == ekUnary
