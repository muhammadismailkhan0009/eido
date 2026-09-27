import std/unittest
import support/compiler_test_support

suite "Class-valued method return flow":
  test "allows bare binding from a detached method result":
    let source = """
      class Account {
        Int balance;

        function snapshot() returns Account {
          var result = copy self;
          return result;
        }
      }

      function main() {
        var account = Account { balance = 100; };
        var snapshot = account.snapshot();
      }
    """

    discard analyzeSource(source)

  test "rejects copy/ref around method results":
    let copied = """
      class Account {
        Int balance;
        function snapshot() returns Account {
          var result = copy self;
          return result;
        }
      }
      function main() {
        var account = Account { balance = 100; };
        var snapshot = copy account.snapshot();
      }
    """
    let aliased = """
      class Account {
        Int balance;
        function snapshot() returns Account {
          var result = copy self;
          return result;
        }
      }
      function main() {
        var account = Account { balance = 100; };
        var snapshot = ref account.snapshot();
      }
    """

    expect ValueError:
      discard analyzeSource(copied)
    expect ValueError:
      discard analyzeSource(aliased)
