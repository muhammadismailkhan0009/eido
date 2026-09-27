import std/unittest
import frontend/lexer/[scanner, token]

suite "Class keyword":
  test "classifies class as a reserved token":
    # Given
    let source = "class classify"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkClass
    check tokens[1].kind == tkIdentifier
    check tokens[2].kind == tkEof
