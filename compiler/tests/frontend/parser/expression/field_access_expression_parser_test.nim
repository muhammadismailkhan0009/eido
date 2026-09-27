import std/unittest
import frontend/ast/[expressions, statements]
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Field access expression parsing":
  test "parses one field access":
    # Given
    let source = """
      function main() {
        var value = point.x;
      }
    """

    # When
    let access =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check access.kind == ekFieldAccess
    check access.target.kind == ekIdentifier
    check access.target.name == "point"
    check access.fieldName == "x"

  test "parses chained field access left to right":
    # Given
    let source = """
      function main() {
        var value = employee.address.zip;
      }
    """

    # When
    let access =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check access.kind == ekFieldAccess
    check access.fieldName == "zip"
    check access.target.kind == ekFieldAccess
    check access.target.fieldName == "address"
    check access.target.target.kind == ekIdentifier
    check access.target.target.name == "employee"

  test "field access binds tighter than arithmetic":
    # Given
    let source = """
      function main() {
        var value = point.x + 1;
      }
    """

    # When
    let expression =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check expression.kind == ekBinary
    check expression.left.kind == ekFieldAccess
    check expression.left.fieldName == "x"

  test "parses field access directly from construction":
    # Given
    let source = """
      class Point { Int x; }
      function main() {
        var value = Point { x = 10; }.x;
      }
    """

    # When
    let access =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check access.kind == ekFieldAccess
    check access.target.kind == ekConstruct
    check access.fieldName == "x"
