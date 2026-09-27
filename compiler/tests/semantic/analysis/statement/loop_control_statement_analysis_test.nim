import std/unittest
import frontend/lexer/scanner
import frontend/parser/program_parser
import hir/statements
import semantic/analysis/program_analysis

suite "Loop control statement semantics":
  test "rejects break outside a loop":
    # Given
    let source = """
      function main() returns Int {
        break;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "rejects continue outside a loop":
    # Given
    let source = """
      function main() returns Int {
        continue;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "accepts break and continue through conditionals inside a loop":
    # Given
    let source = """
      function main() returns Int {
        var count = 0;
        while (count < 3) {
          set count = count + 1;
          if (count == 1) {
            continue;
          }
          if (count == 2) {
            break;
          }
        }
        return count;
      }
    """

    # When
    let program = analyzeProgram(parseProgram(lexAll(source)))
    let loop = program.functions[0].body[1]

    # Then
    check loop.kind == hskWhile
    check loop.body[1].kind == hskIf
    check loop.body[1].thenBranch[0].kind == hskContinue
    check loop.body[2].kind == hskIf
    check loop.body[2].thenBranch[0].kind == hskBreak
