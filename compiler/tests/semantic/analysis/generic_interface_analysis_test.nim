import std/unittest
import support/compiler_test_support
import types/model

suite "Generic interface semantics":
  test "specializes a three-parameter interface with exact substituted types":
    let program = analyzeSource("""
      interface Transform<Source, Config, Destination> {
        function apply(Source value, Config config) returns Destination;
      }
      class TransformInt implements Transform<Int, Bool, Int> {
        Int extra;
        function apply(Int value, Bool config) returns Int {
          if (config) { return value + self.extra; }
          return value;
        }
      }
      function main() {
        var converter = TransformInt { extra = 2; };
      }
    """)

    check program.interfaces.len == 1
    let contract = program.interfaces[0]
    check contract.sourceName == "Transform<Int,Bool,Int>"
    check contract.typ == interfaceType("Transform<Int,Bool,Int>")
    check contract.methods.len == 1
    check contract.methods[0].parameterTypes == @[etInt, etBool]
    check contract.methods[0].result.typ == etInt
    check program.classes[0].implements == @["Transform<Int,Bool,Int>"]

  test "specializes each distinct application exactly once":
    let program = analyzeSource("""
      interface Value<T> {
        function get() returns T;
      }
      class Number implements Value<Int> {
        Int stored;
        function get() returns Int { return self.stored; }
      }
      class Flag implements Value<Bool> {
        Bool stored;
        function get() returns Bool { return self.stored; }
      }
      function read(Value<Int> first, Value<Int> again) returns Int {
        return first.get() + again.get();
      }
      function main() {}
    """)

    check program.interfaces.len == 2
    var intCount = 0
    var boolCount = 0
    for contract in program.interfaces:
      if contract.sourceName == "Value<Int>":
        inc intCount
        check contract.methods[0].result.typ == etInt
      elif contract.sourceName == "Value<Bool>":
        inc boolCount
        check contract.methods[0].result.typ == etBool
      else:
        check false
    check intCount == 1
    check boolCount == 1

  test "specializes nested arguments of a two-parameter interface":
    let program = analyzeSource("""
      interface Lookup<Key, Value> {
        function get(Key key) returns Value;
      }
      class Wrapper<T> {
        T value;
      }
      function consume(Lookup<Int, Wrapper<Bool>> lookup) {}
      function main() {}
    """)

    check program.interfaces.len == 1
    check program.interfaces[0].sourceName == "Lookup<Int,Wrapper<Bool>>"
    check program.interfaces[0].methods[0].parameterTypes == @[etInt]
    check program.interfaces[0].methods[0].result.typ ==
      classType("Wrapper<Bool>")

  test "keeps specialized interface contracts in concrete implementation":
    let program = analyzeSource("""
      interface Bounded<T> {
        function change(T value) returns T {
          require { value > 0; }
          ensure { result >= value; }
        }
      }
      class Counter implements Bounded<Int> {
        Int increment;
        function change(Int value) returns Int {
          return value + self.increment;
        }
      }
      function main() {}
    """)

    check program.interfaces.len == 1
    check program.interfaces[0].methods[0].requires.len == 1
    check program.interfaces[0].methods[0].ensures.len == 1
    check program.classes[0].methods[0].inheritedRequires.len == 1
    check program.classes[0].methods[0].inheritedEnsures.len == 1
    check program.classes[0].methods[0].inheritedRequires[0].interfaceName ==
      "Bounded<Int>"

  test "rejects raw generic interface use":
    expect ValueError:
      discard analyzeSource("""
        interface Value<T> { function get() returns T; }
        function consume(Value value) {}
        function main() {}
      """)

  test "rejects missing and extra interface type arguments":
    expect ValueError:
      discard analyzeSource("""
        interface Pair<A, B> { function choose(A first, B second) returns A; }
        function consume(Pair<Int> item) {}
        function main() {}
      """)

    expect ValueError:
      discard analyzeSource("""
        interface Pair<A, B> { function choose(A first, B second) returns A; }
        function consume(Pair<Int, Bool, String> item) {}
        function main() {}
      """)

  test "rejects duplicate type parameter names on unused interfaces":
    expect ValueError:
      discard analyzeSource("""
        interface Duplicate<T, T> { function get() returns T; }
        function main() {}
      """)

  test "validates invalid member type in an unused generic interface":
    expect ValueError:
      discard analyzeSource("""
        interface Invalid<T> {
          function process(T value) returns Missing;
        }
        function main() {}
      """)

  test "rejects extending a generic parent without explicit generic inheritance":
    expect ValueError:
      discard analyzeSource("""
        interface Parent<T> { function read() returns T; }
        interface Child extends Parent {}
        function main() {}
      """)

  test "rejects generic implementation with the wrong method signature":
    expect ValueError:
      discard analyzeSource("""
        interface Pair<A, B> {
          function first(A value) returns B;
        }
        class Invalid implements Pair<Int, Bool> {
          Int marker;
          function first(Int value) returns Int { return self.marker; }
        }
        function main() {}
      """)

  test "rejects implementing a generic interface with the wrong arity":
    expect ValueError:
      discard analyzeSource("""
        interface Pair<A, B> {
          function first(A value) returns B;
        }
        class Invalid implements Pair<Int> {
          Int marker;
          function first(Int value) returns Int { return self.marker; }
        }
        function main() {}
      """)
