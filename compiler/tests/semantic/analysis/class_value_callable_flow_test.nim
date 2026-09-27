import std/unittest
import support/compiler_test_support

suite "Class-valued callable flow":
  test "accepts class parameters and fresh class returns":
    let source = """
      class Account { Int balance; }

      function create() returns Account {
        return Account { balance = 100; };
      }

      function inspect(Account account) returns Int {
        return account.balance;
      }

      function main() returns Int {
        var account = create();
        return inspect(account);
      }
    """

    discard analyzeSource(source)

  test "rejects returning a class parameter by identity":
    let source = """
      class Account { Int balance; }

      function modify(Account account) returns Account {
        return account;
      }

      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

  test "allows returning a detached copied local":
    let source = """
      class Account { Int balance; }

      function snapshot(Account account) returns Account {
        var detached = copy account;
        return detached;
      }

      function main() {}
    """

    discard analyzeSource(source)

  test "rejects copy and ref syntax directly in return":
    let copied = """
      class Account { Int balance; }
      function snapshot(Account account) returns Account {
        return copy account;
      }
      function main() {}
    """
    let aliased = """
      class Account { Int balance; }
      function leak(Account account) returns Account {
        return ref account;
      }
      function main() {}
    """

    expect ValueError:
      discard analyzeSource(copied)
    expect ValueError:
      discard analyzeSource(aliased)

  test "rejects returning self by identity from a method":
    let source = """
      class Account {
        Int balance;

        function same() returns Account {
          return self;
        }
      }

      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

  test "allows a detached local to be returned from a method":
    let source = """
      class Account {
        Int balance;

        function snapshot() returns Account {
          var result = copy self;
          return result;
        }
      }

      function main() {}
    """

    discard analyzeSource(source)
