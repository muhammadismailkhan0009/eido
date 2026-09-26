import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Class method execution":
  test "method reads own field and combines it with a parameter":
    # Given
    let source = """
      class Account {
        Int balance;

        function remaining(Int amount) returns Int {
          return balance - amount;
        }
      }

      function main() returns Int {
        var account = Account { balance: 100; };
        return account.remaining(20);
      }
    """

    # When
    let output = runFeatureSource(source, "method_field_parameter")

    # Then
    check output == "80"

  test "method body reuses locals and conditional control flow":
    # Given
    let source = """
      class Account {
        Int balance;

        function boundedRemaining(Int amount) returns Int {
          var remaining = balance - amount;
          if (remaining < 0) {
            return 0;
          } else {
            return remaining;
          }
        }
      }

      function main() returns Int {
        var account = Account { balance: 100; };
        return account.boundedRemaining(120);
      }
    """

    # When
    let output = runFeatureSource(source, "method_control_flow")

    # Then
    check output == "0"

  test "zero-result method can be called as a statement":
    # Given
    let source = """
      class Marker {
        function inspect() {}
      }

      function main() {
        var marker = Marker {};
        marker.inspect();
      }
    """

    # When
    let output = runFeatureSource(source, "method_zero_result")

    # Then
    check output == ""

  test "method can call a top-level function":
    # Given
    let source = """
      class Account {
        Int balance;

        function doubled() returns Int {
          return twice(balance);
        }
      }

      function twice(Int value) returns Int {
        return value * 2;
      }

      function main() returns Int {
        var account = Account { balance: 21; };
        return account.doubled();
      }
    """

    # When
    let output = runFeatureSource(source, "method_top_level_call")

    # Then
    check output == "42"

  test "different classes may use the same method name":
    # Given
    let source = """
      class Left {
        function value() returns Int { return 10; }
      }

      class Right {
        function value() returns Int { return 20; }
      }

      function main() returns Int {
        var left = Left {};
        var right = Right {};
        return left.value() + right.value();
      }
    """

    # When
    let output = runFeatureSource(source, "method_same_name_different_classes")

    # Then
    check output == "30"

  test "method call resolves through a class-valued field":
    # Given
    let source = """
      class Account {
        Int balance;

        function value() returns Int {
          return balance;
        }
      }

      class Holder {
        Account account;

        function read() returns Int {
          return account.value();
        }
      }

      function main() returns Int {
        var holder = Holder {
          account: Account { balance: 55; };
        };
        return holder.read();
      }
    """

    # When
    let output = runFeatureSource(source, "method_nested_receiver")

    # Then
    check output == "55"

suite "Class method uniqueness":
  test "field names cannot collide with parameters or locals":
    # Given
    let parameterCollision = """
      class Account {
        Int amount;
        function withdraw(Int amount) returns Int { return amount; }
      }
      function main() {}
    """
    let localCollision = """
      class Account {
        Int balance;
        function inspect() returns Int {
          var balance = 1;
          return balance;
        }
      }
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(parameterCollision)
    expect ValueError:
      discard analyzeSource(localCollision)

  test "parameters locals and nested locals cannot shadow one another":
    # Given
    let parameterLocal = """
      class Account {
        function inspect(Int amount) returns Int {
          var amount = 1;
          return amount;
        }
      }
      function main() {}
    """
    let nestedLocal = """
      class Account {
        function inspect() returns Int {
          var value = 1;
          if (true) {
            var value = 2;
          }
          return value;
        }
      }
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(parameterLocal)
    expect ValueError:
      discard analyzeSource(nestedLocal)

suite "Class method mutation":
  test "own primitive field may be mutated with set":
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
        return account.withdraw(25);
      }
    """

    # When
    let output = runFeatureSource(source, "method_set_own_field")

    # Then
    check output == "75"
