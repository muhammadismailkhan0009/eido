import std/unittest
import frontend/ast/[expressions, statements]
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Class member call parsing":
  test "parses a method call as a value expression":
    # Given
    let source = """
      function main() {
        var remaining = account.remaining(20);
      }
    """

    # When
    let call =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check call.kind == ekMethodCall
    check call.receiver.kind == ekIdentifier
    check call.receiver.name == "account"
    check call.methodName == "remaining"
    check call.methodArguments.len == 1
    check call.methodArguments[0].kind == ekInteger

  test "parses a zero-result method call statement":
    # Given
    let source = """
      function main() {
        account.inspect();
      }
    """

    # When
    let statement = parseProgram(lexAll(source)).functions[0].body[0]

    # Then
    check statement.kind == skCall
    check statement.call.kind == ekMethodCall
    check statement.call.methodName == "inspect"

  test "method calls participate in postfix chains":
    # Given
    let source = """
      function main() {
        var value = holder.account().balance;
      }
    """

    # When
    let access =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check access.kind == ekFieldAccess
    check access.fieldName == "balance"
    check access.target.kind == ekMethodCall
    check access.target.methodName == "account"
