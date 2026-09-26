import std/unittest
import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser
import compiler/hir/[expressions, statements]
import compiler/semantic/analysis/program_analysis
import compiler/types/model

## Runs source through lexer, parser, and semantic analysis without importing backend test support.
proc analyzeSource(source: string): auto =
  analyzeProgram(parseProgram(lexAll(source)))

suite "Field access expression semantics":
  test "resolves primitive field type from a class local":
    # Given
    let source = """
      class Point {
        Int x;
        Bool visible;
      }

      function main() {
        var point = Point {
          x: 10;
          visible: true;
        };
        var value = point.x;
      }
    """

    # When
    let access =
      analyzeSource(source).functions[0].body[1].initializer

    # Then
    check access.kind == hekFieldAccess
    check access.typ == etInt
    check access.sourceFieldName == "x"
    check access.target.kind == hekLocal
    check access.target.typ == classType("Point")

  test "resolves chained access through nominal field types":
    # Given
    let source = """
      class Address { Int zip; }
      class Employee { Address address; }

      function main() {
        var employee = Employee {
          address: Address {
            zip: 54000;
          };
        };
        var zip = employee.address.zip;
      }
    """

    # When
    let access =
      analyzeSource(source).functions[0].body[1].initializer

    # Then
    check access.kind == hekFieldAccess
    check access.typ == etInt
    check access.sourceFieldName == "zip"
    check access.target.kind == hekFieldAccess
    check access.target.typ == classType("Address")
    check access.target.sourceFieldName == "address"

  test "resolves access directly from a construction expression":
    # Given
    let source = """
      class Point { Int x; }
      function main() {
        var value = Point { x: 10; }.x;
      }
    """

    # When
    let access =
      analyzeSource(source).functions[0].body[0].initializer

    # Then
    check access.kind == hekFieldAccess
    check access.typ == etInt
    check access.target.kind == hekConstruct

  test "rejects unknown field on a class":
    # Given
    let source = """
      class Point { Int x; }
      function main() {
        var point = Point { x: 10; };
        var value = point.y;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects field access on a primitive value":
    # Given
    let source = """
      function main() {
        var count = 10;
        var value = count.x;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
