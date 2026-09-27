import std/unittest
import frontend/lexer/[scanner, token]

suite "Lexer scanner":
  test "classifies supported primitive type names as primitive type tokens":
    # Given
    let source = "Bool Byte Short Int Float Char"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens.len == 7
    for index in 0 ..< 6:
      check tokens[index].kind == tkPrimitiveType
    check tokens[^1].kind == tkEof

  test "leaves removed Long and Double names as ordinary identifiers":
    # Given
    let source = "Long Double"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkIdentifier
    check tokens[1].kind == tkIdentifier

  test "classifies String as a built-in type and tokenizes String literals":
    # Given
    let source = "String \"hello\\nworld\" \"\""

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkStringType
    check tokens[1].kind == tkStringLiteral
    check tokens[2].kind == tkStringLiteral
    check tokens[3].kind == tkEof

  test "rejects unterminated and unsupported String escapes":
    expect ValueError:
      discard lexAll("\"unterminated")
    expect ValueError:
      discard lexAll("\"bad\\q\"")

  test "tokenizes unsuffixed Int and Float literals":
    # Given
    let source = "42 2147483648 1.5 2.5"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkInteger
    check tokens[1].kind == tkInteger
    check tokens[2].kind == tkFloat
    check tokens[3].kind == tkFloat

  test "rejects Java numeric type suffixes":
    # Given / When / Then
    expect ValueError:
      discard lexAll("42L")
    expect ValueError:
      discard lexAll("1.5F")
    expect ValueError:
      discard lexAll("2.5D")

  test "rejects an unsupported source character":
    # Given
    let source = "@"

    # When / Then
    expect ValueError:
      discard lexAll(source)

  test "rejects a Char literal containing more than one character":
    # Given
    let source = "'AB'"

    # When / Then
    expect ValueError:
      discard lexAll(source)


  test "tokenizes comparison operators separately from assignment":
    # Given
    let source = "= == != < <= > >="

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkEqual
    check tokens[1].kind == tkEqualEqual
    check tokens[2].kind == tkBangEqual
    check tokens[3].kind == tkLess
    check tokens[4].kind == tkLessEqual
    check tokens[5].kind == tkGreater
    check tokens[6].kind == tkGreaterEqual
    check tokens[7].kind == tkEof

  test "tokenizes field access separator":
    # Given
    let source = "."

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkDot
    check tokens[1].kind == tkEof

  test "tokenizes construction field separator":
    # Given
    let source = ":"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkColon
    check tokens[1].kind == tkEof

  test "tokenizes all three grouping delimiter pairs":
    # Given
    let source = "()[]{}"

    # When
    let tokens = lexAll(source)

    # Then
    check tokens[0].kind == tkLParen
    check tokens[1].kind == tkRParen
    check tokens[2].kind == tkLBracket
    check tokens[3].kind == tkRBracket
    check tokens[4].kind == tkLBrace
    check tokens[5].kind == tkRBrace
    check tokens[6].kind == tkEof
