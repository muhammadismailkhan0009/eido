import std/unittest
import frontend/lexer/[scanner, token]

suite "Conditional keywords":
  test "classifies if and else as reserved tokens":
    # Given
    let source = "if else"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkIf
    check tokens[1].kind == tkElse
    check tokens[2].kind == tkEof
