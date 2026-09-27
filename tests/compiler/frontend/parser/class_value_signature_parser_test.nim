import std/unittest
import compiler/frontend/ast/declarations
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser

suite "Class-valued callable signature parsing":
  test "parses class parameters and class result types":
    let source = """
      class Account { Int balance; }

      function modify(Account account) returns Account {
        return account;
      }

      function main() {}
    """

    let fn = parseProgram(lexAll(source)).functions[0]

    check fn.parameters.len == 1
    check fn.parameters[0].typeRef.name == "Account"
    check fn.result.kind == frrSingle
    check fn.result.typeRef.name == "Account"
