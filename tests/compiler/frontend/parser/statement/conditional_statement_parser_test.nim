import std/unittest
import compiler/frontend/ast/[expressions, statements]
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser

suite "Conditional statement parsing":
  test "parses if without else":
    # Given
    let source = """
      function main() returns Int {
        if (1 < 2) {
          return 7;
        }
        return 0;
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[0]

    # Then
    check statement.kind == skIf
    check statement.condition.kind == ekBinary
    check statement.thenBranch.len == 1
    check statement.thenBranch[0].kind == skReturn
    check statement.elseBranch.len == 0

  test "parses if with else":
    # Given
    let source = """
      function main() returns Int {
        if (true) {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[0]

    # Then
    check statement.kind == skIf
    check statement.thenBranch.len == 1
    check statement.elseBranch.len == 1
    check statement.elseBranch[0].kind == skReturn

  test "parses else if as a nested conditional":
    # Given
    let source = """
      function main() returns Int {
        if (false) {
          return 0;
        } else if (true) {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[0]

    # Then
    check statement.kind == skIf
    check statement.elseBranch.len == 1
    check statement.elseBranch[0].kind == skIf
    check statement.elseBranch[0].thenBranch.len == 1
    check statement.elseBranch[0].elseBranch.len == 1

  test "parses chained else if branches":
    # Given
    let source = """
      function main() returns Int {
        if (false) {
          return 0;
        } else if (false) {
          return 1;
        } else if (true) {
          return 2;
        } else {
          return 3;
        }
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[0]

    # Then
    check statement.elseBranch[0].kind == skIf
    check statement.elseBranch[0].elseBranch[0].kind == skIf

  test "rejects an unparenthesized if condition":
    # Given
    let source = """
      function main() returns Int {
        if true {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))

  test "rejects an unparenthesized else if condition":
    # Given
    let source = """
      function main() returns Int {
        if (false) {
          return 0;
        } else if true {
          return 1;
        } else {
          return 2;
        }
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))
