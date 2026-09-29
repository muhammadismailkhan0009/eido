import std/unittest
import hir/expressions
import support/compiler_test_support
import types/[method_kind, model]

suite "Contract semantics":
  test "requires Boolean contract clauses":
    let source = """
      function checked(Int value) {
        require { value + 1; }
      }
      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

  test "preserves typed require ensure and invariant expressions in HIR":
    let source = """
      class Account {
        Int balance;
        invariant { self.balance >= 0; }

        function debit(Int amount) {
          require { amount > 0; }
          set self.balance = self.balance - amount;
          ensure { self.balance >= 0; }
        }
      }
      function main() {}
    """

    let account = analyzeSource(source).classes[0]
    let debit = account.methods[0]

    check account.invariants.len == 1
    check account.invariants[0].typ == etBool
    check debit.requires.len == 1
    check debit.ensures.len == 1
    check debit.kind == mkInstance

  test "self used only by a contract still makes a method instance-bound":
    let source = """
      class Account {
        Int balance;
        function available() {
          require { self.balance >= 0; }
        }
      }
      function main() {}
    """

    check analyzeSource(source).classes[0].methods[0].kind == mkInstance


  test "types result as the declared function result inside ensure":
    let source = """
      function positive(Int value) returns Int {
        return value;
        ensure { result > 0; }
      }
      function main() {}
    """

    let clause = analyzeSource(source).functions[0].ensures[0]
    check clause.typ == etBool
    check clause.left.typ == etInt

  test "rejects result outside ensure":
    expect ValueError:
      discard analyzeSource("""
        function bad(Int value) returns Int {
          require { result > 0; }
          return value;
        }
        function main() {}
      """)

    expect ValueError:
      discard analyzeSource("""
        function bad(Int value) returns Int {
          return result;
        }
        function main() {}
      """)

  test "rejects result in ensure of a zero-result callable":
    expect ValueError:
      discard analyzeSource("""
        function bad() {
          ensure { result == result; }
        }
        function main() {}
      """)
