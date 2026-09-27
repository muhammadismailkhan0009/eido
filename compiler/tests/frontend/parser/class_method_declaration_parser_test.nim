import std/unittest
import frontend/ast/declarations
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Class method declaration parsing":
  test "parses a method with parameters result and body":
    # Given
    let source = """
      class Account {
        Int balance;

        function remaining(Int amount) returns Int {
          return self.balance - amount;
        }
      }

      function main() {}
    """

    # When
    let program = parseProgram(lexAll(source))
    let account = program.classes[0]

    # Then
    check account.fields.len == 1
    check account.methods.len == 1
    check account.methods[0].name == "remaining"
    check account.methods[0].parameters.len == 1
    check account.methods[0].parameters[0].name == "amount"
    check account.methods[0].result.kind == frrSingle
    check account.methods[0].body.len == 1

  test "allows methods and fields to coexist in either declaration order":
    # Given
    let source = """
      class Account {
        function balanceValue() returns Int {
          return self.balance;
        }

        Int balance;
      }

      function main() {}
    """

    # When
    let account = parseProgram(lexAll(source)).classes[0]

    # Then
    check account.methods.len == 1
    check account.fields.len == 1
    check account.fields[0].name == "balance"

  test "parses a zero-result empty method":
    # Given
    let source = """
      class Marker {
        function inspect() {}
      }

      function main() {}
    """

    # When
    let parsedMethod =
      parseProgram(lexAll(source)).classes[0].methods[0]

    # Then
    check parsedMethod.name == "inspect"
    check parsedMethod.result.kind == frrNone
    check parsedMethod.body.len == 0
