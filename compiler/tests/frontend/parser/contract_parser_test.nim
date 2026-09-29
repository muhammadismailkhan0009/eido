import std/unittest
import frontend/ast/expressions
import support/compiler_test_support

suite "Contract parsing":
  test "parses require and final ensure sections":
    let source = """
      function checked(Int value) returns Int {
        require {
          value > 0;
          value < 100;
        }
        return value;
        ensure {
          value > 0;
        }
      }
      function main() {}
    """

    let fn = parseSource(source).functions[0]

    check fn.requires.len == 2
    check fn.requires[0].kind == ekBinary
    check fn.ensures.len == 1
    check fn.body.len == 1

  test "parses one class invariant section":
    let source = """
      class Account {
        Int balance;
        invariant {
          self.balance >= 0;
        }
      }
      function main() {}
    """

    let account = parseSource(source).classes[0]
    check account.invariants.len == 1

  test "rejects empty and duplicate contract sections":
    expect ValueError:
      discard parseSource("function main() { require {} }")

    expect ValueError:
      discard parseSource("""
        class Account {
          invariant { true; }
          invariant { true; }
        }
        function main() {}
      """)


  test "parses result inside ensure as an expression":
    let source = """
      function positive(Int value) returns Int {
        return value;
        ensure { result > 0; }
      }
      function main() {}
    """

    let clause = parseSource(source).functions[0].ensures[0]
    check clause.kind == ekBinary
    check clause.left.kind == ekIdentifier
    check clause.left.name == "result"


  test "reserves result outside contract result expressions":
    expect ValueError:
      discard parseSource("function bad(Int result) returns Int { return 1; } function main() {}")

    expect ValueError:
      discard parseSource("function bad() { var result = 1; } function main() {}")
