import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Inferred static method execution":
  test "self-free method executes through the class":
    # Given
    let source = """
      class Calculator {
        function add(Int left, Int right) returns Int {
          return left + right;
        }
      }

      function main() returns Int {
        return Calculator.add(20, 22);
      }
    """

    # When
    let output = runFeatureSource(source, "static_method_class_call")

    # Then
    check output == "42"

  test "static method may call another static method through the class":
    # Given
    let source = """
      class Calculator {
        function twice(Int value) returns Int {
          return value * 2;
        }

        function fourTimes(Int value) returns Int {
          return Calculator.twice(Calculator.twice(value));
        }
      }

      function main() returns Int {
        return Calculator.fourTimes(5);
      }
    """

    # When
    let output = runFeatureSource(source, "static_method_static_call")

    # Then
    check output == "20"

  test "static factory returns a fresh class value":
    # Given
    let source = """
      class Point {
        Int x;
        Int y;

        function origin() returns Point {
          return Point { x = 0; y = 0; };
        }
      }

      function main() returns Int {
        var point = Point.origin();
        return point.x + point.y;
      }
    """

    # When
    let output = runFeatureSource(source, "static_method_factory")

    # Then
    check output == "0"

suite "Inferred static method call enforcement":
  test "instance syntax rejects a self-free method":
    # Given
    let source = """
      class Calculator {
        function add(Int left, Int right) returns Int {
          return left + right;
        }
      }

      function main() returns Int {
        var calculator = Calculator {};
        return calculator.add(20, 22);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "class syntax rejects a self-dependent method":
    # Given
    let source = """
      class Account {
        Int balance;
        function value() returns Int { return self.balance; }
      }

      function main() returns Int {
        return Account.value();
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Inferred static method additional execution":
  test "zero-result self-free method executes through the class":
    # Given
    let source = """
      class Marker {
        function inspect() {}
      }

      function main() {
        Marker.inspect();
      }
    """

    # When
    let output = runFeatureSource(source, "static_method_zero_result")

    # Then
    check output == ""

  test "class fields do not make a self-free method instance-bound":
    # Given
    let source = """
      class Account {
        Int balance;
        function defaultBalance() returns Int { return 0; }
      }

      function main() returns Int {
        return Account.defaultBalance();
      }
    """

    # When
    let output = runFeatureSource(source, "static_method_field_independent")

    # Then
    check output == "0"

  test "static keyword is not part of the class method syntax":
    # Given
    let source = """
      class Calculator {
        static function add(Int left, Int right) returns Int {
          return left + right;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
