import std/unittest
import support/feature_test_support

suite "Managed GC execution":
  test "automatic collection preserves precise roots and traced child graphs":
    let output = runFeatureSource("""
      class Child {
        Int value;
      }

      class Parent {
        Child child;
      }

      function main() returns Int {
        var child = Child { value = 42; };
        var parent = Parent { child = ref child; };
        var index = 0;

        while (index < 200) {
          var garbage = Child { value = index; };
          set garbage = Child { value = index + 1; };
          set index = index + 1;
        }

        return parent.child.value;
      }
    """, "managed_gc_root_stress")

    check output == "42"

  test "protects managed call temporaries across nested safepoints":
    let output = runFeatureSource("""
      class Box {
        Int value;
      }

      function make(Int value) returns Box {
        var resultBox = Box { value = value; };
        var index = 0;

        while (index < 200) {
          var garbage = Box { value = index; };
          set garbage = Box { value = index + 1; };
          set index = index + 1;
        }

        return resultBox;
      }

      function sum(Box left, Box right) returns Int {
        return left.value + right.value;
      }

      function main() returns Int {
        return sum(make(11), make(31));
      }
    """, "managed_gc_temporary_arguments")

    check output == "42"

  test "constructed zero-field classes still use managed GC":
    let output = runFeatureSource("""
      class Token {}

      function main() returns Int {
        var token = Token {};
        var index = 0;

        while (index < 100) {
          var garbage = Token {};
          set garbage = Token {};
          set index = index + 1;
        }

        return 7;
      }
    """, "managed_gc_zero_field")

    check output == "7"
