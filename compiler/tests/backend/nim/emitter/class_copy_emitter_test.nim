import std/[strutils, unittest]
import support/compiler_test_support

suite "Class copy emission":
  test "emits a generated copier and copy call":
    let source = """
      class Account { Int balance; }

      function main() {
        var account = Account { balance = 100; };
        var detached = copy account;
      }
    """

    let generated = emitSource(source)

    check "proc eido_copy_Account(" in generated
    check "eido_copy_Account(eido_local_0_account)" in generated

  test "recursively copies class-valued fields":
    let source = """
      class Account { Int balance; }
      class Order { Account account; }

      function main() {
        var account = Account { balance = 100; };
        var order = Order { account = ref account; };
        var detached = copy order;
      }
    """

    let generated = emitSource(source)

    check "eido_copy_Account_internal(" in generated
    check "eido_copy_Order_internal(" in generated
    check "eido_field_account = eido_copy_Account_internal(" in generated
