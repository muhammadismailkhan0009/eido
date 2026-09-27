import std/unittest
import types/model
import support/compiler_test_support

suite "Class declaration semantics":
  test "registers a nominal class type with resolved fields":
    # Given
    let source = """
      class Address {
        Int zip;
      }

      class Employee {
        Address address;
        Bool active;
      }

      function main() {}
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.classes.len == 2
    check program.classes[0].typ == classType("Address")
    check program.classes[1].typ == classType("Employee")
    check program.classes[1].fields[0].sourceName == "address"
    check program.classes[1].fields[0].typ == classType("Address")
    check program.classes[1].fields[1].typ == etBool

  test "resolves a class field type declared later":
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

  test "rejects duplicate class names":
    # Given
    let source = """
      class Point {}
      class Point {}
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects duplicate field names":
    # Given
    let source = """
      class Point {
        Int x;
        Float x;
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects an unknown field type":
    # Given
    let source = """
      class Employee {
        Missing address;
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
