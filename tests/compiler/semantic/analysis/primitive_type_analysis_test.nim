import std/unittest
import compiler/types/model
import support/compiler_test_support

suite "Primitive type analysis":
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

  test "contextually types integer literals for Byte and Short parameters":
    # Given
    let source = """
      function takeByte(Byte value) returns Byte { return value; }
      function takeShort(Short value) returns Short { return value; }
      function main() returns Int {
        takeByte(127);
        takeShort(32767);
        return 0;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[2].body.len == 3

  test "rejects an integer literal outside Byte range":
    # Given
    let source = """
      function takeByte(Byte value) returns Byte { return value; }
      function main() returns Int {
        takeByte(128);
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

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

  test "accepts mixed supported primitive arguments":
    # Given
    let source = """
      function mixed(
        Bool flag,
        Byte tiny,
        Short small,
        Int count,
        Float ratio,
        Char marker
      ) returns Int {
        return count;
      }

      function main() returns Int {
        return mixed(true, 7, 300, 2147483648, 2.5, 'A');
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].parameters[0].typ == etBool
    check program.functions[0].parameters[1].typ == etByte
    check program.functions[0].parameters[2].typ == etShort
    check program.functions[0].parameters[3].typ == etInt
    check program.functions[0].parameters[4].typ == etFloat
    check program.functions[0].parameters[5].typ == etChar

  test "rejects an argument whose primitive type does not match":
    # Given
    let source = """
      function enabled(Bool value) returns Bool { return value; }
      function main() returns Int {
        enabled(1);
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "allows arithmetic only when both operands share Int or Float type":
    # Given
    let validIntSource = """
      function add(Int a, Int b) returns Int { return a + b; }
      function main() returns Int { return add(2147483648, 2); }
    """
    let validFloatSource = """
      function add(Float a, Float b) returns Float { return a + b; }
      function main() returns Int {
        add(1.5, 2.5);
        return 0;
      }
    """
    let mixedSource = """
      function main() returns Float {
        return 1 + 2.5;
      }
    """

    # When
    let intProgram = analyzeSource(validIntSource)
    let floatProgram = analyzeSource(validFloatSource)

    # Then
    check intProgram.functions[0].result.typ == etInt
    check floatProgram.functions[0].result.typ == etFloat
    expect ValueError:
      discard analyzeSource(mixedSource)


  test "allows unary negation for Int and Float":
    # Given
    let source = """
      function negateInt(Int value) returns Int { return -value; }
      function negateFloat(Float value) returns Float { return -value; }
      function main() returns Int {
        negateFloat(2.5);
        return negateInt(5);
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.typ == etInt
    check program.functions[1].result.typ == etFloat

  test "rejects unary negation outside Int and Float":
    # Given
    let byteSource = """
      function negate(Byte value) returns Byte {
        return -value;
      }
      function main() returns Int { return 0; }
    """
    let shortSource = """
      function negate(Short value) returns Short {
        return -value;
      }
      function main() returns Int { return 0; }
    """
    let boolSource = """
      function main() returns Bool {
        return -true;
      }
    """
    let charSource = """
      function main() returns Char {
        return -'A';
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(byteSource)
    expect ValueError:
      discard analyzeSource(shortSource)
    expect ValueError:
      discard analyzeSource(boolSource)
    expect ValueError:
      discard analyzeSource(charSource)
