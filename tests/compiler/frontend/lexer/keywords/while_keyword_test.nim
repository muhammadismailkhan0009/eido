import std/unittest
import compiler/frontend/lexer/[scanner, token]

suite "While keyword":
  test "classifies while as a reserved token":
    # Given
    let source = "while meanwhile"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkWhile
    check tokens[1].kind == tkIdentifier
    check tokens[2].kind == tkEof
