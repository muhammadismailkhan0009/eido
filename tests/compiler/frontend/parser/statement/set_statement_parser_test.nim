import std/unittest
import compiler/frontend/ast/statements
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser

suite "Set statement parsing":
  test "parses explicit set mutation":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        set value = value + 1;
        return value;
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[1]

    # Then
    check statement.kind == skAssign
    check statement.target == "value"

  test "rejects bare reassignment":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        value = value + 1;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))

  test "parses set in a for update clause":
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
    let loop = parseProgram(lexAll(source)).functions[0].body[1]

    # Then
    check loop.kind == skFor
    check loop.forUpdate.kind == skAssign
    check loop.forUpdate.target == "i"
    check loop.forBody[0].kind == skAssign

  test "rejects a bare for update":
    # Given
    let source = """
      function main() {
        for (var i = 0; i < 3; i = i + 1) {
        }
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))
