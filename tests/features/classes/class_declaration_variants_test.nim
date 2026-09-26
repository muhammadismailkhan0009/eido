import std/unittest
import compiler/types/model
import support/compiler_test_support

suite "Class declaration acceptance":
  test "accepts field-only nominal classes":
    # Given
    let source = """
      class Point {
        Int x;
        Int y;
      }

      function main() returns Int {
        return 0;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.classes.len == 1
    check program.classes[0].typ == classType("Point")
    check program.classes[0].fields[0].typ == etInt
    check program.classes[0].fields[1].typ == etInt

  test "accepts an empty class":
    # Given
    let source = """
      class Marker {
      }

      function main() {}
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.classes[0].fields.len == 0

  test "supports forward nominal field references":
    # Given
    let source = """
      class Employee {
        Address address;
      }

      class Address {
        Int zip;
      }

      function main() {}
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.classes[0].fields[0].typ == classType("Address")

  test "rejects unknown nominal field types":
    # Given
    let source = """
      class Employee {
        Unknown address;
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
