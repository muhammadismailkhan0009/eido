import std/unittest
import frontend/ast/[expressions, statements]
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Self expression parsing":
  test "parses self field access":
    let source = """
      class Account {
        Int balance;
        function value() returns Int {
          return self.balance;
        }
      }
      function main() {}
    """

    let access = parseProgram(lexAll(source)).classes[0].methods[0].body[0].value

    check access.kind == ekFieldAccess
    check access.fieldName == "balance"
    check access.target.kind == ekIdentifier
    check access.target.name == "self"

  test "parses self method call":
    let source = """
      class Account {
        function valid() returns Bool { return true; }
        function inspect() returns Bool {
          return self.valid();
        }
      }
      function main() {}
    """

    let call = parseProgram(lexAll(source)).classes[0].methods[1].body[0].value

    check call.kind == ekMethodCall
    check call.receiver.kind == ekIdentifier
    check call.receiver.name == "self"
    check call.methodName == "valid"

  test "parses self method call statement":
    let source = """
      class Marker {
        function inspect() {}
        function run() {
          self.inspect();
        }
      }
      function main() {}
    """

    let statement = parseProgram(lexAll(source)).classes[0].methods[1].body[0]

    check statement.kind == skCall
    check statement.call.kind == ekMethodCall
  test "parses set self field target":
    let source = """
      class Account {
        Int balance;
        function clear() {
          set self.balance = 0;
        }
      }
      function main() {}
    """

    let statement = parseProgram(lexAll(source)).classes[0].methods[0].body[0]

    check statement.kind == skAssign
    check statement.target.kind == ekFieldAccess
    check statement.target.fieldName == "balance"
    check statement.target.target.kind == ekIdentifier
    check statement.target.target.name == "self"
