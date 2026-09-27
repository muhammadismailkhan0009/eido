import std/[strutils, unittest]
import support/compiler_test_support

suite "Generic class emission":
  test "emits concrete specialized class layouts and methods":
    # Given
    let source = """
      class Box<T> {
        T value;

        function add(Int amount) returns Int {
          return self.value + amount;
        }
      }

      function main() returns Int {
        var box = Box<Int> { value = 40; };
        return box.add(2);
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "eido_class_generic_" in generated
    check "eido_field_value: int64" in generated
    check "proc eido_method_0_generic_" in generated

  test "emits different concrete layouts for different specializations":
    # Given
    let source = """
      class Box<T> { T value; }

      function main() {
        var number = Box<Int> { value = 1; };
        var text = Box<String> { value = "one"; };
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check generated.count(" = ref object") == 2
    check "eido_field_value: int64" in generated
    check "eido_field_value: string" in generated
