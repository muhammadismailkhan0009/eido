import std/unittest
import compiler/types/model
import support/compiler_test_support

suite "Unary negation semantics":
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
