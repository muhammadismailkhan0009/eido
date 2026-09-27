import std/unittest
import support/compiler_test_support
import frontend/ast/declarations

suite "Native function parser":
  test "parses a bodyless semicolon terminated native function":
    # Given
    let source = """
      native function platformArgument(Int index) returns String;
      function main() {}
    """

    # When
    let program = parseSource(source)
    let function = program.functions[0]

    # Then
    check function.isNative
    check function.name == "platformArgument"
    check function.parameters.len == 1
    check function.parameters[0].typeRef.name == "Int"
    check function.result.kind == frrSingle
    check function.result.typeRef.name == "String"
    check function.body.len == 0

  test "parses a class-owned bodyless native function":
    # Given
    let source = """
      class Console {
        native function writeLine(String value);
      }
      function main() {}
    """

    # When
    let program = parseSource(source)
    let nativeMethod = program.classes[0].methods[0]

    # Then
    check nativeMethod.isNative
    check nativeMethod.name == "writeLine"
    check nativeMethod.parameters.len == 1
    check nativeMethod.result.kind == frrNone
    check nativeMethod.body.len == 0

  test "requires a semicolon after a native function declaration":
    # Given
    let source = """
      native function platformArgumentCount() returns Int
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard parseSource(source)
