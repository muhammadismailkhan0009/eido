import std/unittest
import frontend/ast/statements
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Loop control statement parsing":
  test "parses break and continue inside a while body":
    # Given
    let source = """
      function main() returns Int {
        while (true) {
          if (true) {
            break;
          }
          continue;
        }
        return 0;
      }
    """

    # When
    let loop = parseProgram(lexAll(source)).functions[0].body[0]

    # Then
    check loop.kind == skWhile
    check loop.body[0].kind == skIf
    check loop.body[0].thenBranch[0].kind == skBreak
    check loop.body[1].kind == skContinue

  test "requires semicolon after break":
    # Given
    let source = """
      function main() returns Int {
        while (true) {
          break
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))

  test "requires semicolon after continue":
    # Given
    let source = """
      function main() returns Int {
        while (true) {
          continue
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))
