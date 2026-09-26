import std/unittest
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser
import compiler/hir/[declarations, expressions, statements]
import compiler/semantic/analysis/program_analysis
import compiler/types/[function_result, model]

## Runs source through lexer, parser, and semantic analysis without backend dependencies.
proc analyzeSource(source: string): auto =
  analyzeProgram(parseProgram(lexAll(source)))

suite "Class method semantics":
  test "analyzes a read-only method with an implicit class receiver":
    # Given
    let source = """
      class Account {
        Int balance;

        function remaining(Int amount) returns Int {
          return balance - amount;
        }
      }

      function main() {}
    """

    # When
    let account = analyzeSource(source).classes[0]
    let analyzedMethod = account.methods[0]

    # Then
    check analyzedMethod.sourceName == "remaining"
    check analyzedMethod.ownerType == classType("Account")
    check analyzedMethod.parameters.len == 1
    check analyzedMethod.parameters[0].sourceName == "amount"
    check analyzedMethod.result.kind == frSingle
    check analyzedMethod.body[0].kind == hskReturn
    check analyzedMethod.body[0].value.kind == hekBinary
    check analyzedMethod.body[0].value.left.kind == hekFieldAccess
    check analyzedMethod.body[0].value.left.sourceFieldName == "balance"

  test "rejects duplicate method names within one class":
    # Given
    let source = """
      class Account {
        function value() returns Int { return 1; }
        function value(Int amount) returns Int { return amount; }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects field and method parameter name collision":
    # Given
    let source = """
      class Account {
        Int amount;

        function withdraw(Int amount) returns Int {
          return amount;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects field and method local name collision":
    # Given
    let source = """
      class Account {
        Int balance;

        function inspect() returns Int {
          var balance = 1;
          return balance;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects method parameter and local name collision":
    # Given
    let source = """
      class Account {
        function inspect(Int amount) returns Int {
          var amount = 1;
          return amount;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects nested local shadowing":
    # Given
    let source = """
      class Account {
        function inspect() returns Int {
          var value = 1;
          if (true) {
            var value = 2;
          }
          return value;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "allows the same parameter names in different methods":
    # Given
    let source = """
      class Calculator {
        function add(Int left, Int right) returns Int {
          return left + right;
        }

        function subtract(Int left, Int right) returns Int {
          return left - right;
        }
      }

      function main() {}
    """

    # When
    let calculator = analyzeSource(source).classes[0]

    # Then
    check calculator.methods.len == 2
    check calculator.methods[0].parameters[0].sourceName == "left"
    check calculator.methods[1].parameters[0].sourceName == "left"
