import std/unittest
import frontend/ast/expressions
import support/compiler_test_support

suite "Call expression parsing":
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
