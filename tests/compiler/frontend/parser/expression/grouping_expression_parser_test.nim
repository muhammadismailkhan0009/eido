import std/unittest
import compiler/frontend/ast/expressions
import support/compiler_test_support

suite "Grouping expression parsing":
  test "parses round square and curly grouping delimiters":
    # Given
    let roundSource = "function main() returns Int { return (1 + 2) * 3; }"
    let squareSource = "function main() returns Int { return [1 + 2] * 3; }"
    let curlySource = "function main() returns Int { return {1 + 2} * 3; }"

    # When
    let roundProgram = parseSource(roundSource)
    let squareProgram = parseSource(squareSource)
    let curlyProgram = parseSource(curlySource)

    # Then
    check roundProgram.functions[0].body[0].value.kind == ekBinary
    check squareProgram.functions[0].body[0].value.kind == ekBinary
    check curlyProgram.functions[0].body[0].value.kind == ekBinary

  test "parses mixed nested grouping delimiters":
    # Given
    let source =
      "function main() returns Int { return [{(1 + 2) * 3} + 4] * 2; }"

    # When
    let program = parseSource(source)

    # Then
    check program.functions[0].body[0].value.kind == ekBinary

  test "rejects mismatched grouping delimiters":
    # Given
    let source = "function main() returns Int { return [1 + 2); }"

    # When / Then
    expect ValueError:
      discard parseSource(source)
