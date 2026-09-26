import std/[strutils, unittest]
import support/compiler_test_support

suite "Class method emission":
  test "emits a method with a hidden receiver and field reads":
    # Given
    let source = """
      class Account {
        Int balance;

        function remaining(Int amount) returns Int {
          return balance - amount;
        }
      }

      function main() {}
    """

    # When
    let generated = emitSource(source)

    # Then
    check "proc eido_method_0_Account_remaining(" in generated
    check "eido_local_0_receiver: eido_class_Account" in generated
    check "eido_local_1_amount: int64" in generated
    check "eido_local_0_receiver.eido_field_balance" in generated

  test "emits a value-returning instance method call":
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
    let generated = emitSource(source)

    # Then
    check "return eido_method_0_Account_remaining(eido_local_0_account, int64(20))" in generated

  test "emits a zero-result instance method call statement":
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
    let generated = emitSource(source)

    # Then
    check "eido_method_0_Marker_inspect(eido_local_0_marker)" in generated
