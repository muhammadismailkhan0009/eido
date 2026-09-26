import std/unittest
import compiler/types/model
import support/compiler_test_support

suite "Arithmetic operator semantics":
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
