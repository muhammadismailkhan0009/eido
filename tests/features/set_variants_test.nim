import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Set execution":
  test "mutates an existing local var":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        set value = value + 2;
        return value;
      }
    """

    # When
    let output = runFeatureSource(source, "set_local")

    # Then
    check output == "7"

  test "mutates an own primitive field inside its class method":
    # Given
    let source = """
      class Account {
        Int balance;

        function withdraw(Int amount) returns Int {
          set balance = balance - amount;
          return balance;
        }
      }

      function main() returns Int {
        var account = Account { balance: 100; };
        return account.withdraw(30);
      }
    """

    # When
    let output = runFeatureSource(source, "set_own_field")

    # Then
    check output == "70"

  test "for update and body mutation use set":
    # Given
    let source = """
      function main() returns Int {
        var total = 0;

        for (var i = 0; i < 4; set i = i + 1) {
          set total = total + i;
        }

        return total;
      }
    """

    # When
    let output = runFeatureSource(source, "set_for")

    # Then
    check output == "6"

  test "replaces a class-valued var only with fresh construction":
    # Given
    let source = """
      class Marker {
        Int value;
      }

      function main() returns Int {
        var marker = Marker { value: 1; };
        set marker = Marker { value: 9; };
        return marker.value;
      }
    """

    # When
    let output = runFeatureSource(source, "set_fresh_class")

    # Then
    check output == "9"

suite "Set rejection boundaries":
  test "bare reassignment is not mutation syntax":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        value = 6;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "parameters cannot be mutated":
    # Given
    let source = """
      function change(Int value) returns Int {
        set value = 6;
        return value;
      }

      function main() returns Int {
        return change(5);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "external field mutation syntax is rejected":
    # Given
    let source = """
      class Account {
        Int balance;
      }

      function main() returns Int {
        var account = Account { balance: 100; };
        set account.balance = 0;
        return account.balance;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "own class-valued fields cannot be mutated yet":
    # Given
    let source = """
      class Address {
        Int zip;
      }

      class Employee {
        Address address;

        function replace() {
          set address = Address { zip: 33100; };
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
