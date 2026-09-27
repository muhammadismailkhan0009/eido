import std/unittest
import frontend/ast/expressions
import support/compiler_test_support

suite "Boolean operator binding":
  test "comparison binds inside word not":
    # Given
    let source = "function main() returns Bool { return not 1 < 2; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekUnary
    check expression.unaryOp == uoNot
    check expression.operand.kind == ekBinary
    check expression.operand.op == boLess

  test "not binds before and":
    # Given
    let source = "function main() returns Bool { return not true and false; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boAnd
    check expression.left.kind == ekUnary
    check expression.left.unaryOp == uoNot

  test "and binds before or":
    # Given
    let source = "function main() returns Bool { return true or false and false; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boOr
    check expression.right.kind == ekBinary
    check expression.right.op == boAnd

  test "word not is recursive":
    # Given
    let source = "function main() returns Bool { return not not true; }"

    # When
    let expression = parseSource(source).functions[0].body[0].value

    # Then
    check expression.kind == ekUnary
    check expression.unaryOp == uoNot
    check expression.operand.kind == ekUnary
    check expression.operand.unaryOp == uoNot
