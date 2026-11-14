import std/unittest
import support/feature_test_support

suite "Generic interface runtime dispatch":
  test "generic interface specialization dispatches through matching generic implementation":
    let output = runFeatureSource("""
      interface Value<T> {
        function get() returns T;
      }

      class Box<T> implements Value<T> {
        T stored;

        function get() returns T {
          return self.stored;
        }

        function create(T value) returns Value<T> {
          return Box<T> { stored = value; };
        }
      }

      function read(Value<Int> value) returns Int {
        return value.get();
      }

      function main() returns Int {
        return read(Box<Int>.create(42));
      }
    """, "generic_interface_dispatch")

    check output == "42"

  test "two-parameter generic interfaces dispatch through generic classes":
    let output = runFeatureSource("""
      interface Pair<Left, Right> {
        function left() returns Left;
        function right() returns Right;
      }

      class PairBox<A, B> implements Pair<A, B> {
        A leftValue;
        B rightValue;

        function left() returns A { return self.leftValue; }
        function right() returns B { return self.rightValue; }

        function make(A first, B second) returns Pair<A, B> {
          return PairBox<A, B> {
            leftValue = first;
            rightValue = second;
          };
        }
      }

      function read(Pair<Int, Bool> pair) returns Int {
        if (pair.right()) { return pair.left(); }
        return 0;
      }

      function main() returns Int {
        return read(PairBox<Int, Bool>.make(42, true));
      }
    """, "generic_interface_pair_dispatch")

    check output == "42"

  test "three generic parameters specialize instance method signatures":
    let output = runFeatureSource("""
      interface Transform<Input, Context, Output> {
        function apply(Input value, Context context) returns Output;
      }

      class Calculator implements Transform<Int, Bool, Int> {
        Int offset;

        function apply(Int value, Bool context) returns Int {
          if (context) { return value + self.offset; }
          return value;
        }

        function create() returns Transform<Int, Bool, Int> {
          return Calculator { offset = 2; };
        }
      }

      function use(Transform<Int, Bool, Int> converter) returns Int {
        return converter.apply(40, true);
      }

      function main() returns Int { return use(Calculator.create()); }
    """, "generic_interface_three_parameters")

    check output == "42"

  test "multiple specializations of one interface dispatch independently":
    let output = runFeatureSource("""
      interface Readable<T> {
        function read() returns T;
      }
      class Number implements Readable<Int> {
        Int value;
        function read() returns Int { return self.value; }
        function create() returns Readable<Int> {
          return Number { value = 42; };
        }
      }
      class Switch implements Readable<Bool> {
        Bool value;
        function read() returns Bool { return self.value; }
        function create() returns Readable<Bool> {
          return Switch { value = true; };
        }
      }
      function main() returns Int {
        var number = Number.create();
        var switch = Switch.create();
        if (switch.read()) { return number.read(); }
        return 0;
      }
    """, "generic_interface_distinct_applications")

    check output == "42"

  test "specialized interface requires and ensures propagate to methods":
    let output = runFeatureSource("""
      interface Increasing<T> {
        function increase(T value) returns T {
          require { value > 0; }
          ensure { result >= value; }
        }
      }
      class Counter implements Increasing<Int> {
        Int amount;
        function increase(Int value) returns Int {
          return value + self.amount;
        }
        function create() returns Increasing<Int> {
          return Counter { amount = 2; };
        }
      }
      function main() returns Int {
        var counter = Counter.create();
        return counter.increase(40);
      }
    """, "generic_interface_contracts")

    check output == "42"

  test "specialized interface preconditions remain enforced at runtime":
    expect OSError:
      discard runFeatureSource("""
        interface Increasing<T> {
          function increase(T value) returns T {
            require { value > 0; }
          }
        }
        class Counter implements Increasing<Int> {
          Int amount;
          function increase(Int value) returns Int {
            return value + self.amount;
          }
          function create() returns Increasing<Int> {
            return Counter { amount = 2; };
          }
        }
        function main() returns Int {
          var counter = Counter.create();
          return counter.increase(0);
        }
      """, "generic_interface_failing_precondition")
