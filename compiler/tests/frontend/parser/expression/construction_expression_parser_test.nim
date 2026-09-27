import std/unittest
import frontend/ast/[expressions, statements]
import frontend/lexer/scanner
import frontend/parser/program_parser

suite "Construction expression parsing":
  test "parses named field initializers":
    # Given
    let source = """
      class Point {
        Int x;
        Int y;
      }

      function main() {
        var point = Point {
          x = 10;
          y = 20;
        };
      }
    """

    # When
    let program = parseProgram(lexAll(source))
    let construction = program.functions[0].body[0].initializer

    # Then
    check construction.kind == ekConstruct
    check construction.constructionTypeRef.name == "Point"
    check construction.fields.len == 2
    check construction.fields[0].name == "x"
    check construction.fields[0].value.kind == ekInteger
    check construction.fields[1].name == "y"

  test "parses nested construction":
    # Given
    let source = """
      class Address { Int zip; }
      class Employee { Address address; }

      function main() {
        var employee = Employee {
          address = Address {
            zip = 54000;
          };
        };
      }
    """

    # When
    let construction =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check construction.kind == ekConstruct
    check construction.fields[0].value.kind == ekConstruct
    check construction.fields[0].value.constructionTypeRef.name == "Address"

  test "parses zero-field construction":
    # Given
    let source = """
      class Marker {}
      function main() {
        var marker = Marker {};
      }
    """

    # When
    let construction =
      parseProgram(lexAll(source)).functions[0].body[0].initializer

    # Then
    check construction.kind == ekConstruct
    check construction.constructionTypeRef.name == "Marker"
    check construction.fields.len == 0

  test "requires semicolon after every field initializer":
    # Given
    let source = """
      class Point { Int x; }
      function main() {
        var point = Point {
          x = 10
        };
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))

  test "rejects colon construction assignment syntax":
    # Given
    let source = """
      class Point { Int x; }
      function main() {
        var point = Point { x: 10; };
      }
    """

    # When / Then
    expect ValueError:
      discard parseProgram(lexAll(source))
