import std/unittest
import types/model
import support/compiler_test_support

suite "Optional semantics":
  test "resolves optional primitive String and class types":
    let source = """
      class User { String name; }
      class Holder {
        Int? count;
        String? label;
        User? user;
      }
      function main() {}
    """

    let program = analyzeSource(source)

    check program.classes[1].fields[0].typ == optionalType(etInt)
    check program.classes[1].fields[1].typ == optionalType(etString)
    check program.classes[1].fields[2].typ == optionalType(classType("User"))

  test "requires exists before consuming an optional local":
    let source = """
      function maybe() returns Int? {
        return 42;
      }

      function main() returns Int {
        var value = maybe();
        return value + 1;
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "narrows an optional local only inside its exists block":
    let validSource = """
      function maybe() returns Int? {
        return 42;
      }

      function main() returns Int {
        var value = maybe();
        if value exists {
          return value + 1;
        }
        return 0;
      }
    """

    let invalidSource = """
      function maybe() returns Int? {
        return 42;
      }

      function main() returns Int {
        var value = maybe();
        if value exists {
        }
        return value + 1;
      }
    """

    discard analyzeSource(validSource)
    expect ValueError:
      discard analyzeSource(invalidSource)

  test "narrows nested optional field paths one proof at a time":
    let source = """
      class City { Int code; }
      class Address { City? city; }
      class Employee { Address? address; }

      function read(Employee employee) returns Int {
        if employee.address exists {
          if employee.address.city exists {
            return employee.address.city.code;
          }
        }
        return 0;
      }

      function main() {}
    """

    discard analyzeSource(source)

  test "does not invalidate a lexical proof after direct none mutation yet":
    let source = """
      class User {
        Int id;
        function value() returns Int {
          return self.id;
        }
      }

      function maybe() returns User? {
        return User { id = 1; };
      }

      function inspect() returns Int {
        var user = maybe();
        if user exists {
          set user = none;
          return user.value();
        }
        return 0;
      }

      function main() {}
    """

    discard analyzeSource(source)
