import std/unittest
import frontend/ast/[expressions, statements]
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "For statement parsing":
  test "parses declaration condition update and body":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;
        for (var i = 0; i < 3; set i = i + 1) {
          set total = total + i;
        }
        return total;
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[1]

    # Then
    check statement.kind == skFor
    check statement.forInitializer.kind == skVar
    check statement.forCondition.kind == ekBinary
    check statement.forUpdate.kind == skAssign
    check statement.forBody.len == 1
    check statement.forBody[0].kind == skAssign

  test "parses a nested for statement":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;
        for (var outer = 0; outer < 2; set outer = outer + 1) {
          for (var inner = 0; inner < 2; set inner = inner + 1) {
            set total = total + 1;
          }
        }
        return total;
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[1]

    # Then
    check statement.kind == skFor
    check statement.forBody[0].kind == skFor

  test "rejects missing for parentheses":
    # Given
    let source = """
      function main() returns Int {
        for var i = 0; i < 3; set i = i + 1 {
          return i;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))
