import std/[unittest, sequtils, strutils]
import support/compiler_test_support

suite "Layout declaration analysis":
  test "preserves unselected layout declarations in HIR":
    let program = analyzeSource("""
      class Family { String father; String mother; }
      layout Compact for Family {
        var shape = Layout.create();
        shape.field("father");
        shape.field("mother");
        return shape;
      }
      layout Aligned for Family {
        var shape = Layout.create();
        shape.align(16);
        return shape;
      }
      function main() {}
    """)
    check program.layouts.len == 2
    check program.layouts[0].sourceName == "Compact"
    check program.layouts[0].targetClass == "Family"
    check "father" in program.layouts[0].bodySource
    check program.layouts[1].sourceName == "Aligned"

  test "unselected layouts do not alter the generated class representation":
    let baseline = emitSource("""
      class Family { Int father; }
      function main() { var family = Family { father = 1; }; }
    """)
    let withLayout = emitSource("""
      class Family { Int father; }
      layout Custom for Family {
        var shape = Layout.create();
        shape.field("father");
        return shape;
      }
      function main() { var family = Family { father = 1; }; }
    """)
    check baseline == withLayout

  test "rejects unknown or non-class layout targets":
    expect ValueError:
      discard analyzeSource("""
        layout Missing for Unknown { return shape; }
        function main() {}
      """)
    expect ValueError:
      discard analyzeSource("""
        interface Named { function name() returns String; }
        layout Wrong for Named { return shape; }
        function main() {}
      """)

  test "rejects duplicate layout names, not multiple layouts per class":
    expect ValueError:
      discard analyzeSource("""
        class Family { Int members; }
        layout Same for Family { return shape; }
        layout Same for Family { return shape; }
        function main() {}
      """)

  test "specializes generic layouts only for used concrete classes":
    let program = analyzeSource("""
      class Pair<A, B> { A first; B second; }
      layout Reverse<T, U> for Pair<T, U> {
        var shape = Layout.create();
        shape.field("second");
        shape.field("first");
        return shape;
      }
      function main() {
        var p = Pair<Int, Bool> { first = 1; second = true; };
      }
    """)
    check program.layouts.len == 1
    check program.layouts[0].sourceName == "Reverse<Int,Bool>"
    check program.layouts[0].targetClass == "Pair<Int,Bool>"

  test "unused generic layout does not instantiate its class":
    let program = analyzeSource("""
      class Pair<T> { T item; }
      layout Compact<U> for Pair<U> { return shape; }
      function main() {}
    """)
    check program.layouts.len == 0
    check program.classes.filterIt(not it.span.embeddedSdk).len == 0

  test "rejects generic layout and target parameter mismatch":
    expect ValueError:
      discard analyzeSource("""
        class Pair<T> { T item; }
        layout Broken for Pair<Int> { return shape; }
        function main() {}
      """)
    expect ValueError:
      discard analyzeSource("""
        class Pair<T> { T item; }
        layout Broken<U> for Pair<T> { return shape; }
        function main() {}
      """)
