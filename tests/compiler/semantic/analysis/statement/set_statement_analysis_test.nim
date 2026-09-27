import std/unittest
import compiler/hir/statements
import support/compiler_test_support

suite "Set statement semantics":
  test "sets an existing primitive var":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        set value = value + 1;
        return value;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[1].kind == hskAssign
    check program.functions[0].body[1].targetName == "value"

  test "allows replacing a class-valued var with a fresh construction":
    # Given
    let source = """
      class Marker {
        Int value;
      }

      function main() returns Int {
        var marker = Marker { value: 1; };
        set marker = Marker { value: 2; };
        return marker.value;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[1].kind == hskAssign
    check program.functions[0].body[1].targetName == "marker"

  test "rejects class-valued var mutation from an existing class value":
    # Given
    let source = """
      class Marker {
        Int value;
      }

      function main() returns Int {
        var first = Marker { value: 1; };
        var second = Marker { value: 2; };
        set second = first;
        return second.value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects parameter mutation":
    # Given
    let source = """
      function change(Int value) returns Int {
        set value = 20;
        return value;
      }

      function main() returns Int {
        return change(10);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects an unknown set target":
    # Given
    let source = """
      function main() returns Int {
        set missing = 10;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "sets an own primitive field inside a method":
    # Given
    let source = """
      class Account {
        Int balance;

        function withdraw(Int amount) returns Int {
          set self.balance = self.balance - amount;
          return self.balance;
        }
      }

      function main() {}
    """

    # When
    let methodBody = analyzeSource(source).classes[0].methods[0].body

    # Then
    check methodBody[0].kind == hskFieldSet
    check methodBody[0].fieldName == "balance"

  test "rejects set on an own class-valued field":
    # Given
    let source = """
      class Address {
        Int zip;
      }

      class Employee {
        Address address;

        function replace() {
          set self.address = Address { zip: 33100; };
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
