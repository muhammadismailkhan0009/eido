import std/unittest
import hir/[expressions, statements]
import types/model
import support/compiler_test_support

suite "Self expression semantics":
  test "resolves self field through current receiver":
    let source = """
      class Account {
        Int balance;
        function value() returns Int {
          return self.balance;
        }
      }
      function main() {}
    """

    let value = analyzeSource(source).classes[0].methods[0].body[0].value

    check value.kind == hekFieldAccess
    check value.sourceFieldName == "balance"
    check value.target.kind == hekLocal
    check value.target.typ == classType("Account")

  test "resolves self method on current receiver":
    let source = """
      class Account {
        function valid() returns Bool { return true; }
        function inspect() returns Bool {
          return self.valid();
        }
      }
      function main() {}
    """

    let value = analyzeSource(source).classes[0].methods[1].body[0].value

    check value.kind == hekMethodCall
    check value.methodCall.methodName == "valid"
    check value.methodCall.receiver.kind == hekLocal
    check value.methodCall.receiver.typ == classType("Account")

  test "self method stays distinct from same named top level function":
    let source = """
      class Account {
        function valid() returns Int { return 1; }
        function inspect() returns Int {
          return self.valid();
        }
      }
      function valid() returns Int { return 2; }
      function main() {}
    """

    let value = analyzeSource(source).classes[0].methods[1].body[0].value
    check value.kind == hekMethodCall
  test "rejects self outside an instance method":
    let source = """
      class Account { Int balance; }
      function main() {
        var account = Account { balance: 1; };
        var value = self.balance;
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects unqualified own field reads":
    let source = """
      class Account {
        Int balance;
        function value() returns Int {
          return balance;
        }
      }
      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects unqualified own field mutation":
    let source = """
      class Account {
        Int balance;
        function clear() {
          set balance = 0;
        }
      }
      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

  test "sets an own primitive field through self":
    let source = """
      class Account {
        Int balance;
        function clear() {
          set self.balance = 0;
        }
      }
      function main() {}
    """

    let statement = analyzeSource(source).classes[0].methods[0].body[0]

    check statement.kind == hskFieldSet
    check statement.fieldName == "balance"
