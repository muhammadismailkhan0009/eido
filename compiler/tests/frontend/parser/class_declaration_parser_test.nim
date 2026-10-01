import std/unittest
import support/compiler_test_support

suite "Class declaration parsing":
  test "parses a class with typed fields":
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
    let program = parseSource(source)

    # Then
    check program.classes.len == 1
    check program.classes[0].name == "Point"
    check program.classes[0].fields.len == 2
    check program.classes[0].fields[0].typeRef.name == "Int"
    check program.classes[0].fields[0].name == "x"
    check program.classes[0].fields[1].typeRef.name == "Int"
    check program.classes[0].fields[1].name == "y"


  test "parses an explicitly class-owned field":
    let source = """
      class Counter {
        Int value;
        Int Counter.count = 0;
      }

      function main() {}
    """

    let counter = parseSource(source).classes[0]

    check counter.fields.len == 2
    check not counter.fields[0].isClassOwned
    check counter.fields[1].isClassOwned
    check counter.fields[1].ownerName == "Counter"
    check counter.fields[1].name == "count"
    check not counter.fields[1].initializer.isNil

  test "requires the owning class qualifier on class-owned fields":
    let source = """
      class Counter {
        Int Other.count = 0;
      }

      function main() {}
    """

    expect ValueError:
      discard parseSource(source)

  test "parses an empty class":
    # Given
    let source = """
      class Marker {
      }

      function main() {}
    """

    # When
    let program = parseSource(source)

    # Then
    check program.classes.len == 1
    check program.classes[0].fields.len == 0

  test "parses a named class type in a field":
    # Given
    let source = """
      class Address {
        Int zip;
      }

      class Employee {
        Address address;
      }

      function main() {}
    """

    # When
    let program = parseSource(source)

    # Then
    check program.classes[1].fields[0].typeRef.name == "Address"
    check program.classes[1].fields[0].name == "address"

  test "requires semicolon after a field":
    # Given
    let source = """
      class Point {
        Int x
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard parseSource(source)

  test "rejects punctuation after a class block":
    # Given
    let source = """
      class Point {
        Int x;
      };

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard parseSource(source)
