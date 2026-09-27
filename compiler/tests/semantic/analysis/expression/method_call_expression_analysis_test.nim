import std/unittest
import frontend/lexer/scanner
import frontend/parser/program_parser
import hir/[expressions, statements]
import semantic/analysis/program_analysis
import types/[function_result, method_kind, model]

## Runs source through lexer, parser, and semantic analysis without backend dependencies.
proc analyzeSource(source: string): auto =
  analyzeProgram(parseProgram(lexAll(source)))

suite "Instance method call semantics":
  test "resolves a value-returning method by receiver class":
    # Given
    let source = """
      class Account {
        Int balance;

        function remaining(Int amount) returns Int {
          return self.balance - amount;
        }
      }

      function main() {
        var account = Account { balance = 100; };
        var value = account.remaining(20);
      }
    """

    # When
    let call =
      analyzeSource(source).functions[0].body[1].initializer

    # Then
    check call.kind == hekMethodCall
    check call.typ == etInt
    check call.methodCall.methodName == "remaining"
    check call.methodCall.kind == mkInstance
    check call.methodCall.receiver.typ == classType("Account")
    check call.methodCall.arguments.len == 1
    check call.methodCall.arguments[0].typ == etInt
    check call.methodCall.result.kind == frSingle

  test "accepts a zero-result instance method call as a statement":
    # Given
    let source = """
      class Marker {
        Bool active;
        function inspect() {
          var current = self.active;
        }
      }

      function main() {
        var marker = Marker { active = true; };
        marker.inspect();
      }
    """

    # When
    let statement = analyzeSource(source).functions[0].body[1]

    # Then
    check statement.kind == hskMethodCall
    check statement.methodCall.methodName == "inspect"
    check statement.methodCall.result.kind == frNone

  test "rejects a zero-result instance method call used as a value":
    # Given
    let source = """
      class Marker {
        Bool active;
        function inspect() {
          var current = self.active;
        }
      }

      function main() {
        var marker = Marker { active = true; };
        var value = marker.inspect();
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects unknown methods and primitive receivers":
    # Given
    let unknown = """
      class Account {}
      function main() {
        var account = Account {};
        account.missing();
      }
    """
    let primitive = """
      function main() {
        var value = 10;
        value.inspect();
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(unknown)
    expect ValueError:
      discard analyzeSource(primitive)

  test "checks method arity and argument types":
    # Given
    let wrongArity = """
      class Account {
        Int balance;
        function remaining(Int amount) returns Int {
          return self.balance - amount;
        }
      }

      function main() {
        var account = Account { balance = 100; };
        var value = account.remaining();
      }
    """
    let wrongType = """
      class Account {
        Int balance;
        function remaining(Int amount) returns Int {
          return self.balance - amount;
        }
      }

      function main() {
        var account = Account { balance = 100; };
        var value = account.remaining(true);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(wrongArity)
    expect ValueError:
      discard analyzeSource(wrongType)

  test "method signatures resolve independent of declaration order":
    # Given
    let source = """
      class Holder {
        Account account;

        function read() returns Int {
          return self.account.value();
        }
      }

      class Account {
        Int balance;

        function value() returns Int {
          return self.balance;
        }
      }

      function main() {}
    """

    # When
    let readMethod = analyzeSource(source).classes[0].methods[0]

    # Then
    check readMethod.body[0].value.kind == hekMethodCall
    check readMethod.body[0].value.typ == etInt
