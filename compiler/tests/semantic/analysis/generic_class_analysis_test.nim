import std/unittest
import types/model
import support/compiler_test_support

suite "Generic class semantics":
  test "specializes a generic class to the concrete type argument":
    # Given
    let source = """
      class Box<T> {
        T value;
      }

      function main() {
        var box = Box<Int> { value = 42; };
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.classes.len == 1
    check program.classes[0].typ == classType("Box<Int>")
    check program.classes[0].fields[0].typ == etInt

  test "specializes nested and multiple type arguments":
    # Given
    let source = """
      class Pair<A, B> {
        A first;
        B second;
      }

      class Box<T> {
        T value;
      }

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
    let program = analyzeSource(source)

    # Then
    check program.classes.len == 2
    check program.classes[0].typ == classType("Pair<String,Int>") or
      program.classes[1].typ == classType("Pair<String,Int>")
    check program.classes[0].typ == classType("Box<Pair<String,Int>>") or
      program.classes[1].typ == classType("Box<Pair<String,Int>>")

  test "rejects raw and wrong-arity generic class usage":
    # Given
    let rawSource = """
      class Box<T> { T value; }
      function main() {
        var box = Box { value = 1; };
      }
    """
    let wrongArity = """
      class Pair<A, B> { A first; B second; }
      function main() {
        var pair = Pair<Int> { first = 1; second = 2; };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(rawSource)
    expect ValueError:
      discard analyzeSource(wrongArity)

  test "rejects duplicate generic type parameter names":
    # Given
    let source = """
      class Pair<T, T> {
        T first;
        T second;
      }
      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Generic template validation":
  test "validates unknown member types even when a generic class is unused":
    # Given
    let source = """
      class Box<T> {
        Missing value;
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "concrete class arguments retain ordinary class-return identity rules":
    # Given
    let source = """
      class Account {
        Int balance;
      }

      class Box<T> {
        T value;

        function get() returns T {
          return self.value;
        }
      }

      function main() {
        var account = Account { balance = 10; };
        var box = Box<Account> { value = ref account; };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
