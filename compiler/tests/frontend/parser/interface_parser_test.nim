import std/unittest
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
