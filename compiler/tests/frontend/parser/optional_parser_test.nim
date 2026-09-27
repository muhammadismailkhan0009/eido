import std/unittest
import frontend/ast/[expressions, statements]
import support/compiler_test_support

suite "Optional parsing":
  test "parses optional field parameter and result types":
    let source = """
      class User {
        String name;
      }

      class Holder {
        User? user;
        Int? count;
      }

      function choose(User? user) returns String? {
        return none;
      }

      function main() {}
    """

    let program = parseSource(source)

    check program.classes[1].fields[0].typeRef.isOptional
    check program.classes[1].fields[1].typeRef.isOptional
    check program.functions[0].parameters[0].typeRef.isOptional
    check program.functions[0].result.typeRef.isOptional
    check program.functions[0].body[0].value.kind == ekNone

  test "parses an exists proof block over a field path":
    let source = """
      class Address { String city; }
      class Employee { Address? address; }

      function inspect(Employee employee) returns String? {
        if employee.address exists {
          return employee.address.city;
        }
        return none;
      }

      function main() {}
    """

    let program = parseSource(source)
    let proof = program.functions[0].body[0]

    check proof.kind == skExists
    check proof.existsTarget.kind == ekFieldAccess
    check proof.existsTarget.fieldName == "address"
    check proof.existsBody.len == 1

  test "keeps ordinary if conditions parenthesized":
    let source = """
      function main() {
        if true exists {}
      }
    """

    expect ValueError:
      discard parseSource(source)
