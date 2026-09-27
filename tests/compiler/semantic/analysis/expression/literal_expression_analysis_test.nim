import std/unittest
import compiler/types/model
import support/compiler_test_support

suite "Literal expression semantics":
  test "resolves every supported primitive result type":
    # Given
    let source = """
      function boolValue() returns Bool { return true; }
      function byteValue() returns Byte { return 7; }
      function shortValue() returns Short { return 300; }
      function intValue() returns Int { return 2147483648; }
      function floatValue() returns Float { return 2.5; }
      function charValue() returns Char { return 'A'; }
      function main() returns Int { return 0; }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etBool
    check program.functions[1].result.typ == etByte
    check program.functions[2].result.typ == etShort
    check program.functions[3].result.typ == etInt
    check program.functions[4].result.typ == etFloat
    check program.functions[5].result.typ == etChar

  test "resolves String as its own built-in semantic type":
    # Given
    let source = """
      function message(String value) returns String { return value; }
      function main() returns String { return message("Eido"); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].parameters[0].typ == etString
    check program.functions[0].result.typ == etString
    check program.functions[1].result.typ == etString

  test "accepts Int values beyond the Java 32 bit int range":
    # Given
    let source = """
      function large() returns Int { return 2147483648; }
      function main() returns Int { return large(); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etInt

  test "accepts ordinary decimal literals as Float":
    # Given
    let source = """
      function ratio() returns Float { return 123456789.125; }
      function main() returns Int {
        ratio();
        return 0;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etFloat
