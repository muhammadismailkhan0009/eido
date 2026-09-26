import std/unittest
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser
import compiler/hir/statements
import compiler/semantic/analysis/program_analysis

suite "For statement semantics":
  test "initializer binding is visible to condition update and body":
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
    let program = analyzeProgram(parseProgram(lexAll(source)))
    let loop = program.functions[0].body[1]

    # Then
    check loop.kind == hskFor
    check loop.forInitializer.kind == hskVar
    check loop.forUpdate.kind == hskAssign
    check loop.forBody.len == 1

  test "rejects a non-Bool for condition":
    # Given
    let source = """
      function main() returns Int {
        for (var i = 0; 1; set i = i + 1) {
          return i;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "initializer binding does not leak after the loop":
    # Given
    let source = """
      function main() returns Int {
        for (var i = 0; i < 1; set i = i + 1) {
        }
        return i;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "body-local declaration is unavailable to the update":
    # Given
    let source = """
      function main() returns Int {
        for (var i = 0; i < 1; set inside = inside + 1) {
          var inside = 0;
        }
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "for does not prove a result function definitely returns":
    # Given
    let source = """
      function value() returns Int {
        for (var i = 0; i < 1; set i = i + 1) {
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
