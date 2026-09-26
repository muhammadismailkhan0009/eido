import std/unittest
import compiler/frontend/lexer/[scanner, token]

suite "Boolean operator keywords":
  test "classifies boolean word operators as reserved tokens":
    # Given
    let source = "not and or"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkNot
    check tokens[1].kind == tkAnd
    check tokens[2].kind == tkOr
    check tokens[3].kind == tkEof