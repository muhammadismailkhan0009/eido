import std/unittest
import support/feature_test_support

suite "Interface runtime dispatch":
  test "factory may hide a concrete implementation behind an interface":
    let output = runFeatureSource("""
      interface Value {
        function value() returns Int;
      }

      class HiddenValue implements Value {
        Int stored;

        function value() returns Int {
          return self.stored;
        }

        function create(Int initialStored) returns Value {
          return HiddenValue { stored = initialStored; };
        }
      }

      function main() returns Int {
        var value = HiddenValue.create(42);
        return value.value();
      }
    """, "interface_hidden_dispatch")

    check output == "42"

  test "one class may dispatch through multiple interfaces":
    let output = runFeatureSource("""
      interface Left {
        function left() returns Int;
      }

      interface Right {
        function right() returns Int;
      }

      class Both implements Left, Right {
        Int value;

        function left() returns Int {
          return self.value;
        }

        function right() returns Int {
          return self.value + 1;
        }

        function asLeft(Int initialValue) returns Left {
          return Both { value = initialValue; };
        }

        function asRight(Int initialValue) returns Right {
          return Both { value = initialValue; };
        }
      }

      function main() returns Int {
        var left = Both.asLeft(20);
        var right = Both.asRight(21);
        return left.left() + right.right();
      }
    """, "interface_multiple_dispatch")

    check output == "42"

  test "child interface inherits parent methods":
    let output = runFeatureSource("""
      interface Base {
        function base() returns Int;
      }

      interface Child extends Base {
        function child() returns Int;
      }

      class Impl implements Child {
        Int value;

        function base() returns Int {
          return self.value;
        }

        function child() returns Int {
          return self.value + 1;
        }

        function create(Int initialValue) returns Child {
          return Impl { value = initialValue; };
        }
      }

      function main() returns Int {
        var item = Impl.create(20);
        return item.base() + item.child();
      }
    """, "interface_extension_dispatch")

    check output == "41"


  test "child interface value upcasts to its parent contract":
    let output = runFeatureSource("""
      interface Base {
        function value() returns Int;
      }

      interface Child extends Base {
        function extra() returns Int;
      }

      class Impl implements Child {
        Int stored;

        function value() returns Int {
          return self.stored;
        }

        function extra() returns Int {
          return self.stored + 1;
        }

        function create() returns Child {
          return Impl { stored = 42; };
        }
      }

      function readBase(Base item) returns Int {
        return item.value();
      }

      function main() returns Int {
        var child = Impl.create();
        return readBase(child);
      }
    """, "interface_parent_upcast")

    check output == "42"

  test "class value converts to interface parameter at call boundary":
    let output = runFeatureSource("""
      interface Value {
        function value() returns Int;
      }

      class Impl implements Value {
        Int stored;

        function value() returns Int {
          return self.stored;
        }
      }

      function read(Value item) returns Int {
        return item.value();
      }

      function main() returns Int {
        return read(Impl { stored = 42; });
      }
    """, "interface_parameter_conversion")

    check output == "42"

  test "zero-result interface method dispatches as a statement":
    let output = runFeatureSource("""
      interface Touch {
        function touch();
      }

      class Impl implements Touch {
        Int touched;

        function touch() {
          set self.touched = 1;
        }

        function create() returns Touch {
          return Impl { touched = 0; };
        }
      }

      function main() {
        var item = Impl.create();
        item.touch();
      }
    """, "interface_zero_result_dispatch")

    check output == ""


  test "generic class specialization preserves implemented interface":
    let output = runFeatureSource("""
      interface Readable {
        function read() returns Int;
      }

      class Box<T> implements Readable {
        T value;
        Int marker;

        function read() returns Int {
          return self.marker;
        }
      }

      function readValue(Readable value) returns Int {
        return value.read();
      }

      function main() returns Int {
        return readValue(Box<Int> { value = 7; marker = 42; });
      }
    """, "generic_class_interface")

    check output == "42"


suite "Interface contract propagation":
  test "inherited interface require is enforced by the implementation":
    expect OSError:
      discard runFeatureSource("""
        interface Service {
          function process(Int value) returns Int {
            require { value > 0; }
          }
        }
        class Impl implements Service {
          Int marker;
          function process(Int value) returns Int {
            return value + self.marker;
          }
          function create() returns Service { return Impl { marker = 0; }; }
        }
        function main() returns Int {
          var service = Impl.create();
          return service.process(0);
        }
      """, "interface_inherited_require")

  test "inherited interface result ensure is enforced by the implementation":
    expect OSError:
      discard runFeatureSource("""
        interface Service {
          function process(Int value) returns Int {
            ensure { result >= 0; }
          }
        }
        class Impl implements Service {
          Int marker;
          function process(Int value) returns Int {
            return -1 + self.marker;
          }
          function create() returns Service { return Impl { marker = 0; }; }
        }
        function main() returns Int {
          var service = Impl.create();
          return service.process(1);
        }
      """, "interface_inherited_ensure")


  test "inherited contracts bind parameters by signature position":
    let output = runFeatureSource("""
      interface Service {
        function process(Int amount) returns Int {
          require { amount > 0; }
          ensure { result == amount; }
        }
      }
      class Impl implements Service {
        Int offset;
        function process(Int value) returns Int {
          return value + self.offset;
        }
        function create() returns Service { return Impl { offset = 0; }; }
      }
      function main() returns Int {
        var service = Impl.create();
        return service.process(42);
      }
    """, "interface_contract_parameter_position")

    check output == "42"


  test "concrete calls also enforce inherited interface contracts":
    expect OSError:
      discard runFeatureSource("""
        interface Service {
          function process(Int value) returns Int {
            require { value > 0; }
          }
        }
        class Impl implements Service {
          Int marker;
          function process(Int value) returns Int {
            return value + self.marker;
          }
        }
        function main() returns Int {
          var service = Impl { marker = 0; };
          return service.process(0);
        }
      """, "interface_contract_concrete_call")


  test "child interface contracts add to inherited parent contracts at runtime":
    expect OSError:
      discard runFeatureSource("""
        interface Base {
          function value() returns Int {
            ensure { result >= 0; }
          }
        }
        interface Child extends Base {
          function value() returns Int {
            ensure { result <= 100; }
          }
        }
        class Impl implements Child {
          Int stored;
          function value() returns Int { return self.stored; }
          function create() returns Child { return Impl { stored = -1; }; }
        }
        function main() returns Int {
          var item = Impl.create();
          return item.value();
        }
      """, "interface_parent_contract_preserved")
