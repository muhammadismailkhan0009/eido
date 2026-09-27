import std/unittest
import frontend/lexer/[scanner, token]

suite "Native function keyword":
  test "classifies native as a reserved declaration keyword":
    # Given / When
    let tokens = lexAll("native function")

    # Then
    check tokens[0].kind == tkNative
    check tokens[1].kind == tkFunction
