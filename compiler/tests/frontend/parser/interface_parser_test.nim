import std/unittest
import frontend/ast/expressions
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Interface parsing":
  test "parses interface method signatures and single extension":
    let program = parseProgram(lexAll("""
      interface Parent {
        function value() returns Int;
      }

      interface Child extends Parent {
        function name() returns String;
      }

      function main() {}
    """))

    check program.interfaces.len == 2
    check program.interfaces[0].name == "Parent"
    check program.interfaces[0].extends.len == 0
    check program.interfaces[0].methods.len == 1
    check program.interfaces[0].methods[0].name == "value"
    check program.interfaces[1].name == "Child"
    check program.interfaces[1].extends == @["Parent"]
    check program.interfaces[1].methods[0].name == "name"

  test "parses multiple implemented interfaces on a class":
    let program = parseProgram(lexAll("""
      interface Readable {
        function read() returns Int;
      }

      interface Writable {
        function write(Int value);
      }

      class Store implements Readable, Writable {
        Int value;

        function read() returns Int {
          return self.value;
        }

        function write(Int value) {
          set self.value = value;
        }
      }

      function main() {}
    """))

    check program.classes.len == 1
    check program.classes[0].implements == @["Readable", "Writable"]


  test "parses module-qualified declared types":
    let program = parseProgram(lexAll("""
      function read(payments.Result value) returns payments.Result {
        return value;
      }

      function main() {}
    """))

    check program.functions[0].parameters[0].typeRef.name == "payments.Result"
    check program.functions[0].result.typeRef.name == "payments.Result"

  test "parses module-qualified construction":
    let program = parseProgram(lexAll("""
      function main() {
        var value = payments.Result { code = 42; };
      }
    """))

    let initializer = program.functions[0].body[0].initializer
    check initializer.kind == ekConstruct
    check initializer.constructionTypeRef.name == "payments.Result"


  test "parses interface require and ensure contracts without a body":
    let program = parseProgram(lexAll("""
      interface Account {
        function withdraw(Int amount) returns Int {
          require { amount > 0; }
          ensure { result >= 0; }
        }
      }
      function main() {}
    """))

    let methodDecl = program.interfaces[0].methods[0]
    check methodDecl.requires.len == 1
    check methodDecl.ensures.len == 1
    check methodDecl.body.len == 0

  test "rejects executable statements inside interface methods":
    expect ValueError:
      discard parseProgram(lexAll("""
        interface Bad {
          function value() returns Int {
            return 1;
          }
        }
        function main() {}
      """))
