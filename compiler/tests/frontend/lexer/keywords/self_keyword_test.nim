import std/unittest
import frontend/lexer/[scanner, token]

suite "Self keyword":
  test "classifies self as a reserved token":
    # Given
    let source = "self selfish"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkSelf
    check tokens[1].kind == tkIdentifier
    check tokens[2].kind == tkEof
