import std/unittest
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser
import compiler/hir/statements
import compiler/semantic/analysis/program_analysis

suite "While statement semantics":
  test "accepts Bool condition and assignment to an outer local":
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
    let program = analyzeProgram(parseProgram(lexAll(source)))
    let loop = program.functions[0].body[1]

    # Then
    check loop.kind == hskWhile
    check loop.body.len == 1
    check loop.body[0].kind == hskAssign

  test "rejects a non-Bool while condition":
    # Given
    let source = """
      function main() returns Int {
        while (1) {
          return 1;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "loop-local declaration does not leak after the loop":
    # Given
    let source = """
      function main() returns Int {
        while (false) {
          var inside = 1;
        }
        return inside;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "while does not prove a result function definitely returns":
    # Given
    let source = """
      function value() returns Int {
        while (true) {
          return 1;
        }
      }

      function main() returns Int {
        return value();
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))
