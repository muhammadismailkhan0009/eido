import std/unittest
import frontend/lexer/scanner
import frontend/parser/program_parser
import hir/[expressions, statements]
import semantic/analysis/program_analysis
import types/model

## Runs source through lexer, parser, and semantic analysis without importing backend test support.
proc analyzeSource(source: string): auto =
  analyzeProgram(parseProgram(lexAll(source)))

suite "Construction expression semantics":
  test "resolves complete named construction independent of field order":
    # Given
    let source = """
      class Point {
        Int x;
        Bool visible;
      }

      function main() {
        var point = Point {
          visible: true;
          x: 10;
        };
      }
    """

    # When
    let program = analyzeSource(source)
    let construction = program.functions[0].body[0].initializer

    # Then
    check construction.kind == hekConstruct
    check construction.typ == classType("Point")
    check construction.constructedTypeName == "Point"
    check construction.fields.len == 2
    check construction.fields[0].sourceName == "visible"
    check construction.fields[0].value.typ == etBool
    check construction.fields[1].sourceName == "x"
    check construction.fields[1].value.typ == etInt

  test "accepts nested and zero-field construction":
    # Given
    let source = """
      class Marker {}
      class Box {
        Marker marker;
      }

      function main() {
        var box = Box {
          marker: Marker {};
        };
      }
    """

    # When
    let construction =
      analyzeSource(source).functions[0].body[0].initializer

    # Then
    check construction.kind == hekConstruct
    check construction.fields[0].value.kind == hekConstruct
    check construction.fields[0].value.typ == classType("Marker")

  test "rejects missing unknown and duplicate fields":
    # Given
    let missing = """
      class Point { Int x; Int y; }
      function main() {
        var point = Point { x: 10; };
      }
    """
    let unknown = """
      class Point { Int x; }
      function main() {
        var point = Point { x: 10; y: 20; };
      }
    """
    let duplicate = """
      class Point { Int x; }
      function main() {
        var point = Point { x: 10; x: 20; };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(missing)
    expect ValueError:
      discard analyzeSource(unknown)
    expect ValueError:
      discard analyzeSource(duplicate)

  test "rejects field initializer type mismatch":
    # Given
    let source = """
      class Point { Int x; }
      function main() {
        var point = Point { x: true; };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "field initializers do not implicitly expose earlier fields":
    # Given
    let source = """
      class Pair {
        Int first;
        Int second;
      }

      function main() {
        var pair = Pair {
          first: 10;
          second: first + 1;
        };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects construction of an unknown class":
    # Given
    let source = """
      function main() {
        var value = Missing {};
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
