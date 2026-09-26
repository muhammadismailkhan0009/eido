import std/unittest
import support/[compiler_test_support, native_test_support]

suite "Supported primitive type values":
  test "Bool parameter + Bool result":
    # Given
    let source = """
      function identity(Bool value) returns Bool {
        return value;
      }

      function main() returns Bool {
        return identity(true);
      }
    """

    # When
    let output = runNativeSource(source, "primitive_bool")

    # Then
    check output == "true"
  test "Byte parameter + Byte result":
    # Given
    let source = """
      function identity(Byte value) returns Byte {
        return value;
      }

      function main() returns Byte {
        return identity(127);
      }
    """

    # When
    let output = runNativeSource(source, "primitive_byte")

    # Then
    check output == "127"
  test "Short parameter + Short result":
    # Given
    let source = """
      function identity(Short value) returns Short {
        return value;
      }

      function main() returns Short {
        return identity(300);
      }
    """

    # When
    let output = runNativeSource(source, "primitive_short")

    # Then
    check output == "300"
  test "Int parameter + Int result supports values beyond 32 bit":
    # Given
    let source = """
      function identity(Int value) returns Int {
        return value;
      }

      function main() returns Int {
        return identity(2147483648);
      }
    """

    # When
    let output = runNativeSource(source, "primitive_int")

    # Then
    check output == "2147483648"
  test "Float parameter + Float result uses ordinary decimal syntax":
    # Given
    let source = """
      function identity(Float value) returns Float {
        return value;
      }

      function main() returns Float {
        return identity(2.5);
      }
    """

    # When
    let output = runNativeSource(source, "primitive_float")

    # Then
    check output == "2.5"
  test "Char parameter + Char result preserves the code unit":
    # Given
    let source = """
      function identity(Char value) returns Char {
        return value;
      }

      function main() returns Char {
        return identity('A');
      }
    """

    # When
    let output = runNativeSource(source, "primitive_char")

    # Then
    check output == "65"

suite "Byte literal bounds":
  test "Byte zero value is accepted":
    # Given
    let source = """
      function identity(Byte value) returns Byte {
        return value;
      }

      function main() returns Byte {
        return identity(0);
      }
    """

    # When
    let output = runNativeSource(source, "primitive_byte_zero")

    # Then
    check output == "0"
  test "Byte value above range is rejected":
    # Given
    let source = """
      function identity(Byte value) returns Byte {
        return value;
      }

      function main() returns Byte {
        return identity(128);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Numeric literal suffix rejection":
  test "numeric L suffix is rejected":
    # Given
    let source = "function main() returns Int { return 42L; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
  test "numeric F suffix is rejected":
    # Given
    let source = "function main() returns Float { return 1.5F; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

suite "Removed numeric type names":
  test "Long type is rejected":
    # Given
    let source = "function main() returns Long { return 1; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
  test "Double type is rejected":
    # Given
    let source = "function main() returns Double { return 1.0; }"

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
