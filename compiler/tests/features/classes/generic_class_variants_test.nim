import std/unittest
import support/[compiler_test_support, feature_test_support]

suite "Generic class execution":
  test "specializes an instance method for a primitive type":
    let source = """
      class Box<T> {
        T value;

        function plus(Int amount) returns Int {
          return self.value + amount;
        }
      }

      function main() returns Int {
        var box = Box<Int> { value = 40; };
        return box.plus(2);
      }
    """

    check runFeatureSource(source, "generic_box_int") == "42"

  test "supports multiple and nested generic applications":
    let source = """
      class Pair<A, B> {
        A first;
        B second;
      }

      class Box<T> {
        T value;
      }

      function main() returns Int {
        var box = Box<Pair<String, Int>> {
          value = Pair<String, Int> {
            first = "age";
            second = 42;
          };
        };
        return box.value.second;
      }
    """

    check runFeatureSource(source, "generic_nested") == "42"

  test "specializes generic dependencies transitively":
    let source = """
      class Box<T> {
        T value;
      }

      class Holder<T> {
        Box<T> box;
      }

      function main() returns Int {
        var holder = Holder<Int> {
          box = Box<Int> { value = 42; };
        };
        return holder.box.value;
      }
    """

    check runFeatureSource(source, "generic_transitive") == "42"

  test "supports more than two generic parameters":
    let source = """
      class Triple<A, B, C> {
        A first;
        B second;
        C third;
      }

      function main() returns Int {
        var triple = Triple<String, Bool, Int> {
          first = "value";
          second = true;
          third = 42;
        };
        return triple.third;
      }
    """

    check runFeatureSource(source, "generic_three_parameters") == "42"

  test "supports class-qualified static methods on a specialization":
    let source = """
      class Box<T> {
        T value;

        function create(T item) returns Box<T> {
          return Box<T> { value = item; };
        }
      }

      function main() returns Int {
        var box = Box<Int>.create(42);
        return box.value;
      }
    """

    check runFeatureSource(source, "generic_static_factory") == "42"

  test "specialized class fields preserve copy and ref semantics":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int {
          return self.balance;
        }
      }

      class Box<T> {
        T value;
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var box = Box<Account> { value = ref account; };
        var detached = copy box;
        detached.value.withdraw(30);
        return account.value() * 1000 + detached.value.value();
      }
    """

    check runFeatureSource(source, "generic_class_copy") == "100070"

suite "Generic class validation":
  test "different specializations are distinct nominal types":
    let source = """
      class Box<T> { T value; }

      function consume(Box<Int> box) returns Int {
        return box.value;
      }

      function main() returns Int {
        var text = Box<String> { value = "hello"; };
        return consume(text);
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "generic functions remain outside the first generic slice":
    let source = """
      function identity<T>(T value) returns T {
        return value;
      }

      function main() returns Int {
        return identity(1);
      }
    """

    expect ValueError:
      discard analyzeSource(source)
