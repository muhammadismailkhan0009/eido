import std/unittest
import hir/expressions
import types/model
import support/compiler_test_support

suite "Interface conformance":
  test "class satisfies an explicitly implemented interface":
    discard analyzeSource("""
      interface Value {
        function value() returns Int;
      }

      class Number implements Value {
        Int stored;

        function value() returns Int {
          return self.stored;
        }
      }

      function main() {}
    """)

  test "rejects missing interface method":
    expect ValueError:
      discard analyzeSource("""
        interface Value {
          function value() returns Int;
        }

        class Number implements Value {
          Int stored;
        }

        function main() {}
      """)

  test "rejects static method as interface implementation":
    expect ValueError:
      discard analyzeSource("""
        interface Value {
          function value() returns Int;
        }

        class Number implements Value {
          function value() returns Int {
            return 42;
          }
        }

        function main() {}
      """)

  test "rejects mismatched interface signature":
    expect ValueError:
      discard analyzeSource("""
        interface Value {
          function value(Int scale) returns Int;
        }

        class Number implements Value {
          Int stored;

          function value() returns Int {
            return self.stored;
          }
        }

        function main() {}
      """)

  test "implementing child interface also requires parent contract":
    expect ValueError:
      discard analyzeSource("""
        interface Base {
          function base() returns Int;
        }

        interface Child extends Base {
          function child() returns Int;
        }

        class Impl implements Child {
          function child() returns Int {
            return 1;
          }
        }

        function main() {}
      """)


  test "interface calls remain explicit dynamic dispatch in HIR":
    let program = analyzeSource("""
      interface Value {
        function value() returns Int;
      }

      class Impl implements Value {
        Int stored;

        function value() returns Int {
          return self.stored;
        }

        function create() returns Value {
          return Impl { stored = 42; };
        }
      }

      function main() returns Int {
        var item = Impl.create();
        return item.value();
      }
    """)

    let call = program.functions[0].body[1].value
    check call.kind == hekMethodCall
    check call.methodCall.dispatchKind == hmdInterface
    check call.methodCall.ownerType.kind == etkInterface
    check call.methodCall.ownerType.interfaceName == "Value"


  test "propagates interface contracts into implementation HIR":
    let program = analyzeSource("""
      interface Account {
        function withdraw(Int amount) returns Int {
          require { amount > 0; }
          ensure { result >= 0; }
        }
      }

      class BankAccount implements Account {
        Int balance;

        function withdraw(Int amount) returns Int {
          require { amount <= self.balance; }
          set self.balance = self.balance - amount;
          return self.balance;
          ensure { result == self.balance; }
        }
      }

      function main() {}
    """)

    let methodDecl = program.classes[0].methods[0]
    check methodDecl.inheritedRequires.len == 1
    check methodDecl.requires.len == 1
    check methodDecl.inheritedEnsures.len == 1
    check methodDecl.ensures.len == 1
    check methodDecl.inheritedRequires[0].interfaceName == "Account"
    check methodDecl.inheritedEnsures[0].interfaceName == "Account"

  test "allows the same inherited declaration through multiple interface paths":
    let program = analyzeSource("""
      interface Base {
        function value() returns Int { ensure { result >= 0; } }
      }
      interface Left extends Base {}
      interface Right extends Base {}

      class Both implements Left, Right {
        Int stored;
        function value() returns Int { return self.stored; }
      }
      function main() {}
    """)

    check program.classes[0].methods[0].inheritedEnsures.len == 1
    check program.classes[0].methods[0].inheritedEnsures[0].interfaceName == "Base"

  test "rejects independent interface declarations of the same method":
    expect ValueError:
      discard analyzeSource("""
        interface Left { function value() returns Int; }
        interface Right { function value() returns Int; }

        class Both implements Left, Right {
          Int stored;
          function value() returns Int { return self.stored; }
        }
        function main() {}
      """)

  test "child redeclaration keeps parent and child contracts":
    let program = analyzeSource("""
      interface Base {
        function value() returns Int { ensure { result >= 0; } }
      }
      interface Child extends Base {
        function value() returns Int { ensure { result <= 100; } }
      }

      class Impl implements Child {
        Int stored;
        function value() returns Int { return self.stored; }
      }
      function main() {}
    """)

    let methodDecl = program.classes[0].methods[0]
    check methodDecl.inheritedEnsures.len == 2
    check methodDecl.inheritedEnsures[0].interfaceName == "Base"
    check methodDecl.inheritedEnsures[1].interfaceName == "Child"


  test "allows interface contracts to observe self through interface methods":
    discard analyzeSource("""
      interface Account {
        function available() returns Int;
        function withdraw(Int amount) returns Int {
          require { amount <= self.available(); }
          ensure { result == self.available(); }
        }
      }

      class Impl implements Account {
        Int balance;
        function available() returns Int { return self.balance; }
        function withdraw(Int amount) returns Int {
          set self.balance = self.balance - amount;
          return self.balance;
        }
      }
      function main() {}
    """)

  test "rejects effectful concrete helpers used by inherited interface contracts":
    expect ValueError:
      discard analyzeSource("""
        interface Account {
          function available() returns Int;
          function withdraw(Int amount) returns Int {
            require { amount <= self.available(); }
          }
        }

        class Impl implements Account {
          Int balance;
          function available() returns Int {
            set self.balance = self.balance + 1;
            return self.balance;
          }
          function withdraw(Int amount) returns Int {
            set self.balance = self.balance - amount;
            return self.balance;
          }
        }
        function main() {}
      """)
