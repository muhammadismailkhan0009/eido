import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Class construction execution":
  test "constructs a complete named class value":
    # Given
    let source = """
      class Point {
        Int x;
        Bool visible;
      }

      function main() {
        var point = Point {
          visible = true;
          x = 10;
        };
      }
    """

    # When
    let output = runFeatureSource(source, "class_construct_complete")

    # Then
    check output == ""

  test "constructs nested and zero-field classes":
    # Given
    let source = """
      class Marker {}
      class Box {
        Marker marker;
      }

      function main() {
        var box = Box {
          marker = Marker {};
        };
      }
    """

    # When
    let output = runFeatureSource(source, "class_construct_nested")

    # Then
    check output == ""

suite "Class construction validation":
  test "requires every declared field exactly once":
    # Given
    let missing = """
      class Point { Int x; Int y; }
      function main() {
        var point = Point { x = 10; };
      }
    """
    let duplicate = """
      class Point { Int x; }
      function main() {
        var point = Point { x = 10; x = 20; };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(missing)
    expect ValueError:
      discard analyzeSource(duplicate)

  test "rejects unknown fields and mismatched initializer types":
    # Given
    let unknown = """
      class Point { Int x; }
      function main() {
        var point = Point { y = 10; };
      }
    """
    let mismatch = """
      class Point { Int x; }
      function main() {
        var point = Point { x = true; };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(unknown)
    expect ValueError:
      discard analyzeSource(mismatch)

  test "does not expose earlier fields as initializer locals":
    # Given
    let source = """
      class Pair { Int first; Int second; }
      function main() {
        var pair = Pair {
          first = 10;
          second = first + 1;
        };
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Class representation boundaries":
  test "class equality is not implicitly introduced":
    # Given
    let source = """
      class Marker {}
      function main() {
        var first = Marker {};
        var second = Marker {};
        var same = first == second;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "setting from an existing class value remains invalid after copy/ref is defined":
    # Given
    let source = """
      class Marker {}
      function main() {
        var first = Marker {};
        var second = Marker {};
        set second = first;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
