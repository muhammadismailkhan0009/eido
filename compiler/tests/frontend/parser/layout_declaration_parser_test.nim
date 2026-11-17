import std/unittest
import frontend/ast/statements
import support/compiler_test_support

suite "Layout declaration parsing":
  test "parses multiple named layouts for one class and preserves Eido bodies":
    let parsed = parseSource("""
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
    check parsed.layouts.len == 2
    check parsed.layouts[0].name == "Compact"
    check parsed.layouts[0].targetType.name == "Family"
    check parsed.layouts[0].body.len == 4
    check parsed.layouts[0].body[0].kind == skVar
    check parsed.layouts[0].body[^1].kind == skReturn
    check parsed.layouts[1].name == "Aligned"
    check parsed.classes.len == 1

  test "parses a generic layout declaration":
    let parsed = parseSource("""
      class Pair<A, B> { A first; B second; }
      layout Reverse<T, U> for Pair<T, U> {
        var shape = Layout.create();
        shape.field("second");
        shape.field("first");
        return shape;
      }
    """)
    let layout = parsed.layouts[0]
    check layout.typeParameters.len == 2
    check layout.typeParameters[0].name == "T"
    check layout.targetType.name == "Pair"
    check layout.targetType.arguments.len == 2

  test "rejects layout bodies without a returned shape":
    expect ValueError:
      discard parseSource("""
        class Family {}
        layout Missing for Family {
          var shape = Layout.create();
        }
      """)

  test "rejects missing for keyword and malformed target":
    expect ValueError:
      discard parseSource("""
        class Family {}
        layout Broken Family { return shape; }
      """)
    expect ValueError:
      discard parseSource("""
        class Family {}
        layout Broken for Family? { return shape; }
      """)

  test "rejects statements following a returned shape":
    # This is a declaration body, not a runtime script.
    expect ValueError:
      discard parseSource("""
        class Family {}
        layout Broken for Family { return shape; var x = 1; }
      """)
