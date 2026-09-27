import std/unittest
import compiler/hir/expressions
import support/compiler_test_support

suite "Class copy/ref semantics":
  test "resolves explicit copy and ref local bindings":
    let source = """
      class Account { Int balance; }
      function main() {
        var account = Account { balance: 100; };
        var detached = copy account;
        var alias = ref account;
      }
    """

    let body = analyzeSource(source).functions[0].body

    check body[1].initializer.kind == hekClassRelation
    check body[1].initializer.classRelationKind == hcvrCopy
    check body[2].initializer.kind == hekClassRelation
    check body[2].initializer.classRelationKind == hcvrRef

  test "rejects bare binding from an existing class value":
    let source = """
      class Account { Int balance; }
      function main() {
        var account = Account { balance: 100; };
        var other = account;
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects copy and ref for primitive values":
    let copied = """
      function main() {
        var value = 10;
        var other = copy value;
      }
    """
    let aliased = """
      function main() {
        var value = 10;
        var other = ref value;
      }
    """

    expect ValueError:
      discard analyzeSource(copied)
    expect ValueError:
      discard analyzeSource(aliased)

  test "rejects copy or ref around callable results":
    let source = """
      class Account { Int balance; }
      function create() returns Account {
        return Account { balance: 100; };
      }
      function main() {
        var account = copy create();
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "requires copy or ref for existing class construction fields":
    let bare = """
      class Account { Int balance; }
      class Order { Account account; }
      function main() {
        var account = Account { balance: 100; };
        var order = Order { account: account; };
      }
    """
    let explicit = """
      class Account { Int balance; }
      class Pair { Account shared; Account detached; }
      function main() {
        var account = Account { balance: 100; };
        var pair = Pair {
          shared: ref account;
          detached: copy account;
        };
      }
    """

    expect ValueError:
      discard analyzeSource(bare)
    discard analyzeSource(explicit)

  test "rejects copy or ref as call arguments":
    let copied = """
      class Account { Int balance; }
      function consume(Account account) {}
      function main() {
        var account = Account { balance: 100; };
        consume(copy account);
      }
    """
    let aliased = """
      class Account { Int balance; }
      class Consumer { function consume(Account account) {} }
      function main() {
        var account = Account { balance: 100; };
        var consumer = Consumer {};
        consumer.consume(ref account);
      }
    """

    expect ValueError:
      discard analyzeSource(copied)
    expect ValueError:
      discard analyzeSource(aliased)
