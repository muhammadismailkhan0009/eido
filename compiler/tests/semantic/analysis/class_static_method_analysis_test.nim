import std/unittest
import hir/expressions
import types/method_kind
import support/compiler_test_support

suite "Inferred static method semantics":
  test "self-free class method is callable through its class":
    # Given
    let source = """
      class Calculator {
        function add(Int left, Int right) returns Int {
          return left + right;
        }
      }

      function main() returns Int {
        return Calculator.add(20, 22);
      }
    """

    # When
    let program = analyzeSource(source)
    let call = program.functions[0].body[0].value

    # Then
    check program.classes[0].methods[0].kind == mkStatic
    check call.kind == hekMethodCall
    check call.methodCall.kind == mkStatic
    check call.methodCall.ownerType.className == "Calculator"

  test "self-free method cannot be called through an instance":
    # Given
    let source = """
      class Calculator {
        function add(Int left, Int right) returns Int {
          return left + right;
        }
      }

      function main() returns Int {
        var calculator = Calculator {};
        return calculator.add(20, 22);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "self-dependent method remains instance-only":
    # Given
    let source = """
      class Account {
        Int balance;
        function value() returns Int { return self.balance; }
      }

      function main() returns Int {
        return Account.value();
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
