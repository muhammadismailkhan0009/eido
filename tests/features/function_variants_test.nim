import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Function signature cardinality variants":
  test "0 params + 0 result: empty function can be called":
    # Given
    let source = """
      function ping() {}

      function main() {
        ping();
      }
    """

    # When
    let output = runFeatureSource(source, "function_0p_0r")

    # Then
    check output == ""
  test "0 params + 1 result: function result can be returned by main":
    # Given
    let source = """
      function value() returns Int {
        return 7;
      }

      function main() returns Int {
        return value();
      }
    """

    # When
    let output = runFeatureSource(source, "function_0p_1r")

    # Then
    check output == "7"
  test "1 param + 0 result: argument can be consumed":
    # Given
    let source = """
      function consume(Int value) {}

      function main() {
        consume(7);
      }
    """

    # When
    let output = runFeatureSource(source, "function_1p_0r")

    # Then
    check output == ""
  test "1 param + 1 result: identity function returns its argument":
    # Given
    let source = """
      function identity(Int value) returns Int {
        return value;
      }

      function main() returns Int {
        return identity(7);
      }
    """

    # When
    let output = runFeatureSource(source, "function_1p_1r")

    # Then
    check output == "7"
  test "2 params + 0 result: both arguments are accepted":
    # Given
    let source = """
      function consume(Int first, Int second) {}

      function main() {
        consume(10, 20);
      }
    """

    # When
    let output = runFeatureSource(source, "function_2p_0r")

    # Then
    check output == ""
  test "2 params + 1 result: function can combine both arguments":
    # Given
    let source = """
      function add(Int first, Int second) returns Int {
        return first + second;
      }

      function main() returns Int {
        return add(10, 20);
      }
    """

    # When
    let output = runFeatureSource(source, "function_2p_1r")

    # Then
    check output == "30"
  test "N params + 0 result: high arity call is accepted":
    # Given
    let source = """
      function consume(
        Int a, Int b, Int c, Int d,
        Int e, Int f, Int g, Int h,
        Int i, Int j, Int k, Int l
      ) {}

      function main() {
        consume(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
      }
    """

    # When
    let output = runFeatureSource(source, "function_np_0r")

    # Then
    check output == ""
  test "N params + 1 result: high arity function can return one argument":
    # Given
    let source = """
      function last(
        Int a, Int b, Int c, Int d,
        Int e, Int f, Int g, Int h,
        Int i, Int j, Int k, Int l
      ) returns Int {
        return l;
      }

      function main() returns Int {
        return last(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
      }
    """

    # When
    let output = runFeatureSource(source, "function_np_1r")

    # Then
    check output == "12"

suite "Zero-result return statements":
  test "0 params + 0 result: explicit bare return is accepted":
    # Given
    let source = """
      function ping() {
        return;
      }

      function main() {
        ping();
      }
    """

    # When
    let output = runFeatureSource(source, "function_0p_0r_return")

    # Then
    check output == ""

suite "Function call resolution":
  test "forward call: caller may appear before callee":
    # Given
    let source = """
      function main() returns Int {
        return later(9);
      }

      function later(Int value) returns Int {
        return value;
      }
    """

    # When
    let output = runFeatureSource(source, "function_forward_call")

    # Then
    check output == "9"

suite "Function call arity":
  test "wrong arity: missing argument is rejected":
    # Given
    let source = """
      function add(Int first, Int second) returns Int {
        return first + second;
      }

      function main() returns Int {
        return add(10);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Function result contracts":
  test "1 result contract: missing return is rejected":
    # Given
    let source = """
      function value() returns Int {}

      function main() returns Int {
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
  test "0 result contract: returning a value is rejected":
    # Given
    let source = """
      function notify() {
        return 1;
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
