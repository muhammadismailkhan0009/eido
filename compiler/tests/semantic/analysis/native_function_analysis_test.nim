import std/unittest
import support/compiler_test_support
import types/[function_result, method_kind]

suite "Native function semantics":
  test "accepts primitive and String native signatures without Eido bodies":
    # Given
    let source = """
      native function platformArgumentCount() returns Int;
      native function platformArgument(Int index) returns String;
      native function platformWriteLine(String value);
      function main() { platformWriteLine(platformArgument(0)); }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].isNative
    check program.functions[0].result.kind == frSingle
    check program.functions[1].isNative
    check program.functions[2].isNative
    check not program.functions[3].isNative

  test "rejects class values across the native boundary":
    # Given
    let source = """
      class Account { Int balance; }
      native function platformSave(Account account);
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects native main as the executable entrypoint":
    # Given
    let source = "native function main();"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "class-owned native function is a static method with no Eido body":
    # Given
    let source = """
      class Process {
        native function argumentCount() returns Int;
      }
      function main() returns Int {
        return Process.argumentCount();
      }
    """

    # When
    let program = analyzeSource(source)
    let nativeMethod = program.classes[0].methods[0]

    # Then
    check nativeMethod.isNative
    check nativeMethod.kind == mkStatic
    check nativeMethod.result.kind == frSingle

  test "class-owned native function rejects class values at ABI boundary":
    # Given
    let source = """
      class Account { Int balance; }
      class NativeStore {
        native function save(Account account);
      }
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
