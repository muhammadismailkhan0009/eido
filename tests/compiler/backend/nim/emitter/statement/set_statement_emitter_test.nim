import std/[strutils, unittest]
import support/compiler_test_support

suite "Set statement emission":
  test "emits local set as Nim reassignment":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        set value = value + 1;
        return value;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "eido_local_0_value = (eido_local_0_value + int64(1))" in generated

  test "emits own field set through the hidden receiver":
    # Given
    let source = """
      class Account {
        Int balance;

        function withdraw(Int amount) returns Int {
          set balance = balance - amount;
          return balance;
        }
      }

      function main() {}
    """

    # When
    let generated = emitSource(source)

    # Then
    check "eido_local_0_receiver.eido_field_balance = " &
      "(eido_local_0_receiver.eido_field_balance - eido_local_1_amount)" in generated
