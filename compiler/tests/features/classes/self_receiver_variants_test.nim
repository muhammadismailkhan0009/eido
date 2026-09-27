import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Self receiver execution":
  test "reads and mutates own field through self":
    let source = """
      class Account {
        Int balance;

        function withdraw(Int amount) returns Int {
          set self.balance = self.balance - amount;
          return self.balance;
        }
      }

      function main() returns Int {
        var account = Account { balance: 100; };
        return account.withdraw(30);
      }
    """

    let output = runFeatureSource(source, "self_field_read_set")

    check output == "70"

  test "calls another method on the current instance through self":
    let source = """
      class Account {
        Int balance;
        function value() returns Int {
          return self.balance;
        }

        function inspect() returns Int {
          return self.value();
        }
      }

      function main() returns Int {
        var account = Account { balance: 42; };
        return account.inspect();
      }
    """

    let output = runFeatureSource(source, "self_method_call")

    check output == "42"

  test "self method remains distinct from same named top level function":
    let source = """
      class Account {
        Int code;
        function value() returns Int { return self.code; }

        function inspect() returns Int {
          return self.value();
        }
      }

      function value() returns Int { return 99; }

      function main() returns Int {
        var account = Account { code: 1; };
        return account.inspect();
      }
    """

    let output = runFeatureSource(source, "self_method_vs_top_level")

    check output == "1"

suite "Self receiver rejection":
  test "rejects unqualified own field access":
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
  test "rejects self outside an instance method":
    let source = """
      class Account { Int balance; }

      function main() returns Int {
        var account = Account { balance: 1; };
        return self.balance;
      }
    """

    expect ValueError:
      discard analyzeSource(source)

suite "Self receiver call separation":
  test "bare same named call remains a top level function call":
    let source = """
      class Account {
        Int marker;
        function value() returns Int { return 1; }

        function inspect() returns Int {
          return value() + (self.marker - self.marker);
        }
      }

      function value() returns Int { return 99; }

      function main() returns Int {
        var account = Account { marker: 1; };
        return account.inspect();
      }
    """

    let output = runFeatureSource(source, "bare_call_top_level")

    check output == "99"
