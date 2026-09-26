import std/unittest
import compiler/frontend/ast/[expressions, statements]
import support/compiler_test_support

suite "Primitive literal parser":
  test "parses Bool Int Float and Char literal forms":
    # Given
    let source = """
      function boolValue() returns Bool { return true; }
      function intValue() returns Int { return 2147483648; }
      function floatValue() returns Float { return 2.5; }
      function charValue() returns Char { return 'A'; }
      function main() returns Int { return 0; }
    """

    # When
    let program = parseSource(source)

    # Then
    check program.functions[0].body[0].value.kind == ekBoolean
    check program.functions[1].body[0].value.kind == ekInteger
    check program.functions[2].body[0].value.kind == ekFloat
    check program.functions[3].body[0].value.kind == ekChar

  test "decodes a Unicode Char escape to one 16 bit code unit":
    # Given
    let source = """
      function letter() returns Char { return '\u0041'; }
      function main() returns Int { return 0; }
    """

    # When
    let program = parseSource(source)
    let character = program.functions[0].body[0].value

    # Then
    check character.kind == ekChar
    check character.charValue == 65'u16
