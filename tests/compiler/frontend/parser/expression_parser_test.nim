import std/unittest
import compiler/frontend/ast/[expressions, statements]
import support/compiler_test_support

suite "Expression parser":
  test "binds multiplication before addition":
    # Given
    let source = "function main() returns Int { return 10 + 20 * 3; }"

    # When
    let program = parseSource(source)
    let expression = program.functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boAdd
    check expression.right.kind == ekBinary
    check expression.right.op == boMultiply

  test "parses a function call as an expression":
    # Given
    let source = """
      function add(Int a, Int b) returns Int { return a + b; }
      function main() returns Int { return add(10, 20); }
    """

    # When
    let program = parseSource(source)
    let expression = program.functions[1].body[0].value

    # Then
    check expression.kind == ekCall
    check expression.callee == "add"
    check expression.arguments.len == 2


  test "parses round square and curly grouping delimiters":
    # Given
    let roundSource = "function main() returns Int { return (1 + 2) * 3; }"
    let squareSource = "function main() returns Int { return [1 + 2] * 3; }"
    let curlySource = "function main() returns Int { return {1 + 2} * 3; }"

    # When
    let roundProgram = parseSource(roundSource)
    let squareProgram = parseSource(squareSource)
    let curlyProgram = parseSource(curlySource)

    # Then
    check roundProgram.functions[0].body[0].value.kind == ekBinary
    check squareProgram.functions[0].body[0].value.kind == ekBinary
    check curlyProgram.functions[0].body[0].value.kind == ekBinary

  test "parses mixed nested grouping delimiters":
    # Given
    let source =
      "function main() returns Int { return [{(1 + 2) * 3} + 4] * 2; }"

    # When
    let program = parseSource(source)

    # Then
    check program.functions[0].body[0].value.kind == ekBinary

  test "rejects mismatched grouping delimiters":
    # Given
    let source = "function main() returns Int { return [1 + 2); }"

    # When / Then
    expect ValueError:
      discard parseSource(source)


  test "binds unary minus before multiplication":
    # Given
    let source = "function main() returns Int { return -2 * 3; }"

    # When
    let program = parseSource(source)
    let expression = program.functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boMultiply
    check expression.left.kind == ekUnary
    check expression.left.unaryOp == uoNegate

  test "allows unary minus to wrap a grouped expression":
    # Given
    let source = "function main() returns Int { return -(2 + 3); }"

    # When
    let program = parseSource(source)
    let expression = program.functions[0].body[0].value

    # Then
    check expression.kind == ekUnary
    check expression.operand.kind == ekBinary

  test "parses repeated unary minus recursively":
    # Given
    let source = "function main() returns Int { return --5; }"

    # When
    let program = parseSource(source)
    let expression = program.functions[0].body[0].value

    # Then
    check expression.kind == ekUnary
    check expression.operand.kind == ekUnary

suite "Comparison expression binding":
  test "binds arithmetic before ordered comparison":
    # Given
    let source = "function main() returns Bool { return 1 + 2 < 4 * 2; }"

    # When
    let program = parseSource(source)
    let expression = program.functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boLess
    check expression.left.op == boAdd
    check expression.right.op == boMultiply

  test "binds ordered comparison before equality":
    # Given
    let source = "function main() returns Bool { return 1 < 2 == true; }"

    # When
    let program = parseSource(source)
    let expression = program.functions[0].body[0].value

    # Then
    check expression.kind == ekBinary
    check expression.op == boEqual
    check expression.left.kind == ekBinary
    check expression.left.op == boLess

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
