import std/unittest
import compiler/frontend/ast/[expressions, statements]
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser

suite "Class copy/ref parsing":
  test "parses copy and ref local initializers":
    let source = """
      class Account { Int balance; }
      function main() {
        var account = Account { balance: 100; };
        var detached = copy account;
        var alias = ref account;
      }
    """

    let body = parseProgram(lexAll(source)).functions[0].body

    check body[1].initializer.kind == ekClassRelation
    check body[1].initializer.relationKind == cvrCopy
    check body[1].initializer.relatedValue.kind == ekIdentifier
    check body[2].initializer.kind == ekClassRelation
    check body[2].initializer.relationKind == cvrRef

  test "parses copy and ref in class construction fields":
    let source = """
      class Account { Int balance; }
      class Pair { Account first; Account second; }
      function main() {
        var account = Account { balance: 100; };
        var pair = Pair {
          first: ref account;
          second: copy account;
        };
      }
    """

    let fields = parseProgram(lexAll(source)).functions[0].body[1].initializer.fields

    check fields[0].value.kind == ekClassRelation
    check fields[0].value.relationKind == cvrRef
    check fields[1].value.kind == ekClassRelation
    check fields[1].value.relationKind == cvrCopy
