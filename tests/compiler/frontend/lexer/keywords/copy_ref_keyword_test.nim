import std/unittest
import compiler/frontend/lexer/[scanner, token]

suite "Copy/ref keywords":
  test "classifies copy and ref as reserved tokens":
    # Given
    let source = "copy ref copycat reference"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkCopy
    check tokens[1].kind == tkRef
    check tokens[2].kind == tkIdentifier
    check tokens[3].kind == tkIdentifier
    check tokens[4].kind == tkEof
