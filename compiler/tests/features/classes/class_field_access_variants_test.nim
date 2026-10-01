import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Class field access execution":
  test "reads a primitive field from a class local":
    # Given
    let source = """
      class Point { Int x; }

      function main() returns Int {
        var point = Point { x = 10; };
        return point.x;
      }
    """

    # When
    let output = runFeatureSource(source, "class_field_read")

    # Then
    check output == "10"

  test "reads through a nested class field chain":
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
    let output = runFeatureSource(source, "class_field_nested_read")

    # Then
    check output == "54000"

  test "field access participates in ordinary expressions":
    # Given
    let source = """
      class Point { Int x; }

      function main() returns Int {
        var point = Point { x = 10; };
        return point.x + 2;
      }
    """

    # When
    let output = runFeatureSource(source, "class_field_expression")

    # Then
    check output == "12"

  test "reads directly from a fresh construction":
    # Given
    let source = """
      class Point { Int x; }

      function main() returns Int {
        return Point { x = 10; }.x;
      }
    """

    # When
    let output = runFeatureSource(source, "class_field_direct_construct")

    # Then
    check output == "10"


  test "class-owned state is shared while instance state stays per object":
    let source = """
      class Counter {
        Int value;
        Int Counter.count = 0;

        function increment() {
          set self.value = self.value + 1;
          set Counter.count = Counter.count + 1;
        }
      }

      function main() returns Int {
        var first = Counter { value = 0; };
        var second = Counter { value = 0; };
        first.increment();
        second.increment();
        return first.value + second.value + Counter.count;
      }
    """

    check runFeatureSource(source, "class_owned_state") == "4"

suite "Class field access validation":
  test "rejects unknown fields and primitive receivers":
    # Given
    let unknown = """
      class Point { Int x; }
      function main() {
        var point = Point { x = 10; };
        var value = point.y;
      }
    """
    let primitive = """
      function main() {
        var count = 10;
        var value = count.x;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(unknown)
    expect ValueError:
      discard analyzeSource(primitive)


  test "keeps class-owned and instance field access explicit":
    let classThroughSelf = """
      class Counter {
        Int value;
        Int Counter.count = 0;
        function invalid() returns Int {
          return self.count;
        }
      }
      function main() {}
    """
    let instanceThroughClass = """
      class Counter { Int value; }
      function main() returns Int {
        return Counter.value;
      }
    """

    expect ValueError:
      discard analyzeSource(classThroughSelf)
    expect ValueError:
      discard analyzeSource(instanceThroughClass)

suite "Class field access representation boundaries":
  test "class-valued field access cannot create an implicit alias or copy":
    # Given
    let source = """
      class Address { Int zip; }
      class Employee { Address address; }

      function main() {
        var employee = Employee {
          address = Address { zip = 54000; };
        };
        var address = employee.address;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "class-valued field access cannot be reassigned implicitly":
    # Given
    let source = """
      class Marker {}
      class Box { Marker marker; }

      function main() {
        var first = Box { marker = Marker {}; };
        var second = Marker {};
        set second = first.marker;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
