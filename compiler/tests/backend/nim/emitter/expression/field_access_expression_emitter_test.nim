import std/[strutils, unittest]
import support/compiler_test_support

suite "Field access expression emission":
  test "emits access from a class local":
    # Given
    let source = """
      class Point { Int x; }
      function main() returns Int {
        var point = Point { x = 10; };
        return point.x;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "return eido_get_Point_x(eido_local_0_point)" in generated

  test "emits chained field access":
    # Given
    let source = """
      class Address { Int zip; }
      class Employee { Address address; }

      function main() returns Int {
        var employee = Employee {
          address = Address { zip = 54000; };
        };
        return employee.address.zip;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "return eido_get_Address_zip(eido_get_Employee_address(eido_local_0_employee))" in generated

  test "emits access directly from construction":
    # Given
    let source = """
      class Point { Int x; }
      function main() returns Int {
        return Point { x = 10; }.x;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "return eido_get_Point_x(eidoGcProtected(eido_construct_Point(arg_eido_field_x = int64(10))))" in generated
