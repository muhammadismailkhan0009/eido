import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Optional execution":
  test "uses a present optional primitive inside exists":
    let source = """
      function maybe(Bool present) returns Int? {
        if (present) {
          return 42;
        }
        return none;
      }

      function main() returns Int {
        var value = maybe(true);
        if value exists {
          return value;
        }
        return 0;
      }
    """

    check runFeatureSource(source, "optional_present_int") == "42"

  test "skips an exists block for none":
    let source = """
      function maybe() returns Int? {
        return none;
      }

      function main() returns Int {
        var value = maybe();
        if value exists {
          return value;
        }
        return 7;
      }
    """

    check runFeatureSource(source, "optional_none_int") == "7"

  test "supports optional class fields without source-level unwrap":
    let source = """
      class Child {
        Int value;
      }

      class Holder {
        Child? child;
      }

      function main() returns Int {
        var holder = Holder {
          child = Child { value = 42; };
        };

        if holder.child exists {
          return holder.child.value;
        }

        return 0;
      }
    """

    check runFeatureSource(source, "optional_class_field") == "42"

  test "supports nested optional field proofs":
    let source = """
      class City {
        Int code;
      }

      class Address {
        City? city;
      }

      class Employee {
        Address? address;
      }

      function main() returns Int {
        var employee = Employee {
          address = Address {
            city = City { code = 42; };
          };
        };

        if employee.address exists {
          if employee.address.city exists {
            return employee.address.city.code;
          }
        }

        return 0;
      }
    """

    check runFeatureSource(source, "optional_nested_fields") == "42"

suite "Optional validation":
  test "rejects member access on an unproven optional":
    let source = """
      class User { Int id; }

      function maybe() returns User? {
        return User { id = 1; };
      }

      function main() returns Int {
        var user = maybe();
        return user.id;
      }
    """

    expect ValueError:
      discard analyzeSource(source)
