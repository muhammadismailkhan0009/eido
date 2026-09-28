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
