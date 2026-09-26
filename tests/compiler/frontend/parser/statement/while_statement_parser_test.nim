import std/unittest
import compiler/frontend/ast/[expressions, statements]
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser

suite "While statement parsing":
  test "parses a parenthesized while condition and body":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        while (count < 3) {
          count = count + 1;
        }
        return count;
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[1]

    # Then
    check statement.kind == skWhile
    check statement.whileCondition.kind == ekBinary
    check statement.body.len == 1
    check statement.body[0].kind == skAssign

  test "parses a nested while statement":
    # Given
    let source = """
      function main() returns Int {
        var outer = 0;
        while (outer < 2) {
          var inner = 0;
          while (inner < 2) {
            inner = inner + 1;
          }
          outer = outer + 1;
        }
        return outer;
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[1]

    # Then
    check statement.kind == skWhile
    check statement.body[1].kind == skWhile

  test "rejects an unparenthesized while condition":
    # Given
    let source = """
      function main() returns Int {
        while true {
          return 1;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))
