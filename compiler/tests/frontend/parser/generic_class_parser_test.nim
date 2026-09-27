import std/unittest
import frontend/ast/expressions
import support/compiler_test_support

suite "Generic class parsing":
  test "parses class type parameters and generic field applications":
    # Given
    let source = """
      class Pair<A, B> {
        A first;
        B second;
      }

      class Holder {
        Pair<String, Int> pair;
      }

      function main() {}
    """

    # When
    let program = parseSource(source)

    # Then
    check program.classes[0].typeParameters.len == 2
    check program.classes[0].typeParameters[0].name == "A"
    check program.classes[0].typeParameters[1].name == "B"
    check program.classes[0].fields[0].typeRef.name == "A"
    check program.classes[1].fields[0].typeRef.name == "Pair"
    check program.classes[1].fields[0].typeRef.arguments.len == 2
    check program.classes[1].fields[0].typeRef.arguments[0].name == "String"
    check program.classes[1].fields[0].typeRef.arguments[1].name == "Int"

  test "parses nested generic class construction":
    # Given
    let source = """
      class Box<T> { T value; }
      class Pair<A, B> { A first; B second; }

      function main() {
        var value = Box<Pair<String, Int>> {
          value = Pair<String, Int> {
            first = "age";
            second = 42;
          };
        };
      }
    """

    # When
    let program = parseSource(source)
    let construction = program.functions[0].body[0].initializer

    # Then
    check construction.kind == ekConstruct
    check construction.constructionTypeRef.name == "Box"
    check construction.constructionTypeRef.arguments.len == 1
    check construction.constructionTypeRef.arguments[0].name == "Pair"
    check construction.constructionTypeRef.arguments[0].arguments.len == 2

  test "parses a generic class type as a static method receiver":
    # Given
    let source = """
      class Box<T> {
        function create(T value) returns Box<T> {
          return Box<T> { value = value; };
        }
        T value;
      }

      function main() {
        var box = Box<Int>.create(42);
      }
    """

    # When
    let program = parseSource(source)
    let call = program.functions[0].body[0].initializer

    # Then
    check call.kind == ekMethodCall
    check call.receiver.kind == ekTypeReference
    check call.receiver.referencedTypeRef.name == "Box"
    check call.receiver.referencedTypeRef.arguments[0].name == "Int"
