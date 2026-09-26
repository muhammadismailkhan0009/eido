import std/unittest
import compiler/frontend/lexer/[scanner, token]

suite "For keyword":
  test "classifies for as a reserved token":
    # Given
    let source = "for format"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkFor
    check tokens[1].kind == tkIdentifier
    check tokens[2].kind == tkEof
