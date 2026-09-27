import std/[strutils, unittest]
import support/compiler_test_support

suite "Nim emitter":
  test "emits backend representations for supported primitives":
    # Given
    let source = """
      function boolValue() returns Bool { return true; }
      function byteValue() returns Byte { return 7; }
      function shortValue() returns Short { return 300; }
      function intValue() returns Int { return 2147483648; }
      function floatValue() returns Float { return 2.5; }
      function charValue() returns Char { return 'A'; }
      function main() returns Int { return 0; }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "): bool" in generated
    check "): int8" in generated
    check "): int16" in generated
    check "): int64" in generated
    check "): float64" in generated
    check "): uint16" in generated
    check "): int32" notin generated
    check "): float32" notin generated

  test "emits String as Nim string with escaped literals and concatenation":
    # Given
    let source = """
      function join(String name) returns String {
        return "Hello\n" + name;
      }
      function main() returns String { return join("Eido"); }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "): string" in generated
    check "\"Hello\\x0A\"" in generated
    check " & eido_local_0_name" in generated

  test "uses semantic IDs in generated local names":
    # Given
    let source = """
      function main() returns Int {
        var salary = 5000;
        var total = salary + 500;
        return total;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "var eido_local_0_salary: int64 = int64(5000)" in generated
    check "var eido_local_1_total: int64 = (eido_local_0_salary + int64(500))" in generated

  test "emits reassignment to the existing generated local":
    # Given
    let source = """
      function main() returns Int {
        var salary = 5000;
        set salary = salary + 500;
        return salary;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "eido_local_0_salary = (eido_local_0_salary + int64(500))" in generated

  test "emits forward declarations before function bodies":
    # Given
    let source = """
      function main() returns Int { return add(10, 20); }
      function add(Int a, Int b) returns Int { return a + b; }
    """

    # When
    let generated = emitSource(source)
    let addSignature =
      "proc eido_fn_1_add(eido_local_0_a: int64, eido_local_1_b: int64): int64"

    # Then
    check addSignature in generated
    check generated.find(addSignature & "\n") <
      generated.find("proc eido_fn_0_main(): int64 =")
    check "return eido_fn_1_add(int64(10), int64(20))" in generated

  test "emits a zero result function without a Nim result type":
    # Given
    let source = """
      function ping() {}
      function main() { ping(); }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "proc eido_fn_0_ping()" in generated
    check "proc eido_fn_0_ping() =\n  discard" in generated

  test "calls zero result main directly from the development harness":
    # Given
    let source = "function main() {}"

    # When
    let generated = emitSource(source)

    # Then
    check "when isMainModule:\n  eido_fn_0_main()" in generated

  test "discards a returned value when call is used as a statement":
    # Given
    let source = """
      function value() returns Int { return 5; }
      function main() { value(); }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "discard eido_fn_0_value()" in generated

  test "uses integer division for Int operands":
    # Given
    let source = """
      function half(Int value) returns Int { return value / 2; }
      function main() returns Int { return half(10); }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "(eido_local_0_value div int64(2))" in generated

  test "uses slash division for Float operands":
    # Given
    let source = """
      function half(Float value) returns Float { return value / 2.0; }
      function main() returns Int {
        half(10.0);
        return 0;
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "(eido_local_0_value / float64(2.0))" in generated


suite "Comparison emission":
  test "emits equality and ordered comparison operators":
    # Given
    let source = """
      function same(Int a, Int b) returns Bool { return a == b; }
      function lower(Int a, Int b) returns Bool { return a < b; }
      function main() returns Bool { return same(1, 1) == lower(1, 2); }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "(eido_local_0_a == eido_local_1_b)" in generated
    check "(eido_local_0_a < eido_local_1_b)" in generated

suite "Unary numeric negation emission":
  test "emits unary numeric negation":
    # Given
    let source = """
      function negate(Int value) returns Int {
        return -value;
      }

      function main() returns Int {
        return negate(5);
      }
    """

    # When
    let generated = emitSource(source)

    # Then
    check "return (-eido_local_0_value)" in generated
