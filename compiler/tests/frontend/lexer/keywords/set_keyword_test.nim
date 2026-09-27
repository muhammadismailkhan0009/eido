import std/unittest
import frontend/lexer/[scanner, token]

suite "Set keyword":
  test "classifies set as a reserved token":
    # Given
    let source = "set setting"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkSet
    check tokens[1].kind == tkIdentifier
    check tokens[2].kind == tkEof
