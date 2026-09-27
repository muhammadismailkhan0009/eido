import std/[strutils, unittest]
import support/compiler_test_support

suite "Inferred static method emission":
  test "emits no hidden receiver and calls through class semantics":
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
    let generated = emitSource(source)

    # Then
    check "proc eido_method_0_Calculator_add(" in generated
    check "eido_class_Calculator" notin
      generated.split("proc eido_method_0_Calculator_add(")[1].split(")")[0]
    check "return eido_method_0_Calculator_add(int64(20), int64(22))" in generated
