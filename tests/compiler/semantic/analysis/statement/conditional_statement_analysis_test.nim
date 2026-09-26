import std/unittest
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser
import compiler/hir/statements
import compiler/semantic/analysis/program_analysis
import compiler/semantic/symbols/ids

suite "Conditional statement semantics":
  test "accepts Bool condition and both returning branches":
    # Given
    let source = """
      function choose(Bool flag) returns Int {
        if (flag) {
          return 1;
        } else {
          return 2;
        }
      }

      function main() returns Int {
        return choose(true);
      }
    """

    # When
    let program = analyzeProgram(parseProgram(lexAll(source)))

    # Then
    check program.functions[0].body.len == 1

  test "rejects non-Bool condition":
    # Given
    let source = """
      function main() returns Int {
        if (1) {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "branch-local declaration does not leak outside its branch":
    # Given
    let source = """
      function main() returns Int {
        if (true) {
          var inside = 1;
        }
        return inside;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "requires all final conditional branches to return in result function":
    # Given
    let source = """
      function value(Bool flag) returns Int {
        if (flag) {
          return 1;
        } else {
          var fallback = 2;
        }
      }

      function main() returns Int {
        return value(true);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "allocates unique local IDs across sibling branches":
    # Given
    let source = """
      function main() returns Int {
        if (true) {
          var left = 1;
        } else {
          var right = 2;
        }
        return 0;
      }
    """

    # When
    let program = analyzeProgram(parseProgram(lexAll(source)))
    let conditional = program.functions[0].body[0]

    # Then
    check conditional.kind == hskIf
    check conditional.thenBranch[0].localId.value !=
      conditional.elseBranch[0].localId.value

  test "accepts an all-returning else if chain":
    # Given
    let source = """
      function classify(Int value) returns Int {
        if (value < 0) {
          return -1;
        } else if (value == 0) {
          return 0;
        } else if (value < 10) {
          return 1;
        } else {
          return 2;
        }
      }

      function main() returns Int {
        return classify(5);
      }
    """

    # When
    let program = analyzeProgram(parseProgram(lexAll(source)))

    # Then
    check program.functions[0].body.len == 1
    check program.functions[0].body[0].kind == hskIf

  test "rejects a non-Bool else if condition":
    # Given
    let source = """
      function main() returns Int {
        if (false) {
          return 0;
        } else if (1) {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))

  test "else if chain without final else does not definitely return":
    # Given
    let source = """
      function classify(Int value) returns Int {
        if (value < 0) {
          return -1;
        } else if (value == 0) {
          return 0;
        }
      }

      function main() returns Int {
        return classify(1);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeProgram(parseProgram(lexAll(source)))
