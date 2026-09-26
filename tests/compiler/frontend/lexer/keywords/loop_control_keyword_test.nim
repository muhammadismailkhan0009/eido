import std/unittest
import compiler/frontend/lexer/[scanner, token]

suite "Loop control keywords":
  test "classifies break and continue as reserved tokens":
    # Given
    let source = "break continue breakpoint continued"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkBreak
    check tokens[1].kind == tkContinue
    check tokens[2].kind == tkIdentifier
    check tokens[3].kind == tkIdentifier
    check tokens[4].kind == tkEof
