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
    check program.classes[0].implements.len == 2
    check program.classes[0].implements[0].name == "Readable"
    check program.classes[0].implements[0].arguments.len == 0
    check program.classes[0].implements[1].name == "Writable"

  test "parses generic interfaces and generic implementations":
    let program = parseProgram(lexAll("""
      interface Value<T> {
        function get() returns T;
      }

      class IntValue implements Value<Int> {
        Int stored;
        function get() returns Int { return self.stored; }
      }

      function main() {}
    """))

    check program.interfaces[0].typeParameters.len == 1
    check program.interfaces[0].typeParameters[0].name == "T"
    check program.interfaces[0].methods[0].result.typeRef.name == "T"
    check program.classes[0].implements[0].name == "Value"
    check program.classes[0].implements[0].arguments.len == 1
    check program.classes[0].implements[0].arguments[0].name == "Int"


  test "parses interfaces with three type parameters and multi-argument implementations":
    let program = parseProgram(lexAll("""
      interface Convert<Input, Context, Output> {
        function convert(Input value, Context context) returns Output;
      }
      class Converter implements Convert<Int, Bool, String> {
        Int marker;
        function convert(Int value, Bool context) returns String {
          return "converted";
        }
      }
      function main() {}
    """))

    let contract = program.interfaces[0]
    check contract.typeParameters.len == 3
    check contract.typeParameters[0].name == "Input"
    check contract.typeParameters[1].name == "Context"
    check contract.typeParameters[2].name == "Output"
    check contract.methods[0].parameters[0].typeRef.name == "Input"
    check contract.methods[0].parameters[1].typeRef.name == "Context"
    check contract.methods[0].result.typeRef.name == "Output"
    let implemented = program.classes[0].implements[0]
    check implemented.name == "Convert"
    check implemented.arguments.len == 3
    check implemented.arguments[0].name == "Int"
    check implemented.arguments[1].name == "Bool"
    check implemented.arguments[2].name == "String"

  test "rejects empty generic interface parameter list":
    expect ValueError:
      discard parseProgram(lexAll("""
        interface Empty<> { function get() returns Int; }
        function main() {}
      """))

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
