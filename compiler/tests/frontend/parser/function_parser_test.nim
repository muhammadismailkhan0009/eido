import std/unittest
import frontend/ast/[declarations, statements]
import support/compiler_test_support

suite "Function parser":
  test "parses Java style typed parameters":
    # Given
    let source = """
      function convert(Int value, Bool enabled, Float ratio) returns Int {
        return value;
      }
      function main() returns Int { return 0; }
    """

    # When
    let program = parseSource(source)
    let function = program.functions[0]

    # Then
    check function.parameters.len == 3
    check function.parameters[0].typeRef.name == "Int"
    check function.parameters[0].name == "value"
    check function.parameters[1].typeRef.name == "Bool"
    check function.parameters[2].typeRef.name == "Float"

  test "parses an arbitrary number of parameters":
    # Given
    let source = """
      function many(
        Int a, Int b, Int c, Int d,
        Int e, Int f, Int g, Int h,
        Int i, Int j, Int k, Int l
      ) returns Int {
        return l;
      }
      function main() returns Int { return 0; }
    """

    # When
    let program = parseSource(source)

    # Then
    check program.functions[0].parameters.len == 12

  test "parses a function without a result":
    # Given
    let source = """
      function notify(Int id) {
        return;
      }
      function main() {}
    """

    # When
    let program = parseSource(source)

    # Then
    check program.functions[0].result.kind == frrNone
    check program.functions[0].body[^1].kind == skReturn
    check program.functions[0].body[^1].value.isNil

  test "parses a function with one result":
    # Given
    let source = "function main() returns Int { return 10; }"

    # When
    let program = parseSource(source)

    # Then
    check program.functions[0].result.kind == frrSingle
    check program.functions[0].result.typeRef.name == "Int"

  test "requires a semicolon after return":
    # Given
    let source = "function main() returns Int { return 10 }"

    # When / Then
    expect ValueError:
      discard parseSource(source)

  test "requires a semicolon after assignment":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        value = 6
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard parseSource(source)

  test "rejects punctuation after a function block":
    # Given
    let comma = "function main() returns Int { return 10; },"
    let semicolon = "function main() returns Int { return 10; };"

    # When / Then
    expect ValueError:
      discard parseSource(comma)
    expect ValueError:
      discard parseSource(semicolon)


  test "rejects removed Long and Double parameter types":
    # Given
    let longSource = """
      function value(Long input) returns Int { return 0; }
      function main() returns Int { return 0; }
    """
    let doubleSource = """
      function value(Double input) returns Int { return 0; }
      function main() returns Int { return 0; }
    """

    # When / Then
    expect ValueError:
      discard parseSource(longSource)
    expect ValueError:
      discard parseSource(doubleSource)
