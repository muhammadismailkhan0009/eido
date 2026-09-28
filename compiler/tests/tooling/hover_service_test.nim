import std/[strutils, unittest]
import support/compiler_test_support
import tooling/hover_service

suite "Semantic hover tooling":
  test "returns inferred local type from typed HIR":
    let source = """
      function main() returns Int {
        var value = 41;
        return value + 1;
      }
    """
    let program = analyzeSource(source)
    let offset = source.rfind("value +")

    let hover = hoverInfoAt(program, "", offset)

    check hover.found
    check hover.contents == "value: Int"

  test "returns field type at field access":
    let source = """
      class Box {
        Int value;
      }

      function main() returns Int {
        var box = Box { value = 42; };
        return box.value;
      }
    """
    let program = analyzeSource(source)
    let offset = source.rfind("value;")

    let hover = hoverInfoAt(program, "", offset)

    check hover.found
    check hover.contents == "value: Int"
