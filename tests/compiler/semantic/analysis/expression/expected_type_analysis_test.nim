import std/unittest
import compiler/types/model
import support/compiler_test_support

suite "Expected expression type semantics":
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
