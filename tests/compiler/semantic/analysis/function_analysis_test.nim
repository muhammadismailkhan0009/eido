import std/unittest
import compiler/hir/[expressions, statements]
import compiler/types/function_result
import support/compiler_test_support

suite "Function analysis":
  test "resolves a call to a function declared later":
    # Given
    let source = """
      function main() returns Int { return add(10, 20); }
      function add(Int a, Int b) returns Int { return a + b; }
    """

    # When
    let program = analyzeSource(source)
    let returnedCall = program.functions[0].body[0].value

    # Then
    check returnedCall.kind == hekCall
    check returnedCall.call.functionName == "add"
    check returnedCall.call.arguments.len == 2

  test "rejects a call to an unknown function":
    # Given
    let source = "function main() returns Int { return missing(10); }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects a call with the wrong number of arguments":
    # Given
    let source = """
      function add(Int a, Int b) returns Int { return a + b; }
      function main() returns Int { return add(10); }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "accepts a high arity call when every argument is present":
    # Given
    let source = """
      function many(
        Int a, Int b, Int c, Int d,
        Int e, Int f, Int g, Int h,
        Int i, Int j, Int k, Int l
      ) returns Int {
        return l;
      }
      function main() returns Int {
        return many(1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12);
      }
    """

    # When
    let program = analyzeSource(source)
    let returnedCall = program.functions[1].body[0].value

    # Then
    check returnedCall.call.arguments.len == 12

  test "rejects duplicate parameter names":
    # Given
    let source = """
      function add(Int value, Int value) returns Int { return value; }
      function main() returns Int { return add(1, 2); }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "requires main to have no parameters":
    # Given
    let source = "function main(Int value) returns Int { return value; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "accepts an empty zero result function":
    # Given
    let source = """
      function ping() {}
      function main() { ping(); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].result.kind == frNone
    check program.functions[1].body[0].kind == hskCall

  test "accepts a bare return in a zero result function":
    # Given
    let source = """
      function ping() { return; }
      function main() { ping(); return; }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[0].kind == hskReturn
    check program.functions[0].body[0].value.isNil

  test "rejects a value returned from a zero result function":
    # Given
    let source = """
      function ping() { return 1; }
      function main() { ping(); }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "requires a value from a single result function":
    # Given
    let missingReturn = """
      function value() returns Int {}
      function main() returns Int { return 0; }
    """
    let bareReturn = """
      function value() returns Int { return; }
      function main() returns Int { return 0; }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(missingReturn)
    expect ValueError:
      discard analyzeSource(bareReturn)

  test "rejects a zero result call used as a value":
    # Given
    let source = """
      function ping() {}
      function main() returns Int {
        var value = ping();
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "allows a value returning call to be used as a statement":
    # Given
    let source = """
      function value() returns Int { return 5; }
      function main() { value(); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[1].body[0].kind == hskCall
    check program.functions[1].body[0].call.result.kind == frSingle
