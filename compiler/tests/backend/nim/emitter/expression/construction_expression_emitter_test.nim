import std/[strutils, unittest]
import support/compiler_test_support

suite "Construction expression emission":
  test "emits class declarations and named construction":
    # Given
    let source = """
      class Point {
        Int x;
        Bool visible;
      }

      function main() {
        var point = Point {
          visible: true;
          x: 10;
        };
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "type\n  eido_class_Point = ref object" in generated
    check "eido_field_x: int64" in generated
    check "eido_field_visible: bool" in generated
    check "eido_class_Point(" in generated
    check "eido_field_visible: true" in generated
    check "eido_field_x: int64(10)" in generated

  test "emits nested construction":
    # Given
    let source = """
      class Marker {}
      class Box { Marker marker; }

      function main() {
        var box = Box {
          marker: Marker {};
        };
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "eido_field_marker: eido_class_Marker()" in generated
