import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Design by Contract execution":
  test "accepts satisfied require ensure and invariant clauses":
    let source = """
      class Account {
        Int balance;
        invariant { self.balance >= 0; }

        function debit(Int amount) {
          require { amount > 0; amount <= self.balance; }
          set self.balance = self.balance - amount;
          ensure { self.balance >= 0; }
        }
      }
      function main() {
        var account = Account { balance = 10; };
        account.debit(4);
      }
    """

    check runFeatureSource(source, "contracts_satisfied") == ""

  test "rejects a failed require clause at runtime":
    let source = """
      function checked(Int value) {
        require { value > 0; }
      }
      function main() { checked(0); }
    """

    expect OSError:
      discard runFeatureSource(source, "require_failed")

  test "rejects an invalid constructed class invariant":
    let source = """
      class Account {
        Int balance;
        invariant { self.balance >= 0; }
      }
      function main() {
        var account = Account { balance = -1; };
      }
    """

    expect OSError:
      discard runFeatureSource(source, "invariant_construct_failed")

  test "rechecks class invariant after instance method execution":
    let source = """
      class Account {
        Int balance;
        invariant { self.balance >= 0; }
        function breakState() {
          set self.balance = -1;
        }
      }
      function main() {
        var account = Account { balance = 1; };
        account.breakState();
      }
    """

    expect OSError:
      discard runFeatureSource(source, "invariant_method_failed")


suite "Contract call safety":
  test "allows compiler-inferred observational helper calls":
    let source = """
      function positive(Int value) returns Bool {
        return value > 0;
      }

      function checked(Int value) {
        require { positive(value); }
      }

      function main() { checked(1); }
    """

    check runFeatureSource(source, "contract_safe_helper") == ""

  test "rejects effectful helper calls before execution":
    let source = """
      class Account {
        Int balance;

        function mutateAndCheck() returns Bool {
          set self.balance = self.balance + 1;
          return true;
        }

        function checked() {
          require { self.mutateAndCheck(); }
        }
      }

      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

suite "Contract boundary semantics":
  test "invariant may call an observational instance helper without recursion":
    let source = """
      class Account {
        Int balance;

        invariant { self.valid(); }

        function valid() returns Bool {
          return self.balance >= 0;
        }
      }

      function main() {
        var account = Account { balance = 1; };
      }
    """

    check runFeatureSource(source, "invariant_helper_no_recursion") == ""

  test "rejects an invariant-breaking field mutation immediately":
    let source = """
      class Account {
        Int balance;

        invariant { self.balance > 0; }

        function breakThenRepair() {
          set self.balance = 0;
          set self.balance = 1;
        }
      }

      function main() {
        var account = Account { balance = 1; };
        account.breakThenRepair();
      }
    """

    expect OSError:
      discard runFeatureSource(source, "invariant_immediate_mutation")

  test "nested method calls check the same object invariant":
    let source = """
      class Account {
        Int balance;

        invariant { self.balance > 0; }

        function observe() {
          if (self.balance > 0) {}
        }

        function useNestedCall() {
          self.observe();
        }
      }

      function main() {
        var account = Account { balance = 1; };
        account.useNestedCall();
      }
    """

    check runFeatureSource(source, "invariant_nested_call_checked") == ""

  test "ensure runs on an early nested return":
    let source = """
      function checked(Int value) returns Int {
        if (value > 0) {
          return value;
        }
        return 0;
        ensure { value < 0; }
      }

      function main() { checked(1); }
    """

    expect OSError:
      discard runFeatureSource(source, "ensure_early_return")

  test "ensure runs on normal void fallthrough":
    let source = """
      function checked(Int value) {
        ensure { value > 0; }
      }

      function main() { checked(0); }
    """

    expect OSError:
      discard runFeatureSource(source, "ensure_void_fallthrough")


suite "Postcondition result binding":
  test "result refers to every successful return value":
    let source = """
      function absolute(Int value) returns Int {
        if (value < 0) {
          return -value;
        }
        return value;
        ensure { result >= 0; }
      }

      function main() {
        absolute(-5);
        absolute(7);
      }
    """

    check runFeatureSource(source, "ensure_result_all_returns") == ""

  test "result checks the actual value chosen by each return path":
    let source = """
      function choose(Bool positive) returns Int {
        if (positive) {
          return 1;
        }
        return -1;
        ensure { result > 0; }
      }

      function main() { choose(false); }
    """

    expect OSError:
      discard runFeatureSource(source, "ensure_result_failed_path")


  test "result supports class member checks":
    let source = """
      class Box {
        Int value;
      }

      function makeBox(Int value) returns Box {
        return Box { value = value; };
        ensure { result.value == value; }
      }

      function main() {
        makeBox(9);
      }
    """

    check runFeatureSource(source, "ensure_result_class_member") == ""


  test "result works for class-owned methods":
    let source = """
      class Numbers {
        function absolute(Int value) returns Int {
          if (value < 0) {
            return -value;
          }
          return value;
          ensure { result >= 0; }
        }
      }

      function main() {
        Numbers.absolute(-4);
      }
    """

    check runFeatureSource(source, "ensure_method_result") == ""
