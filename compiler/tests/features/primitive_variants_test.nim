import std/unittest
import support/[compiler_test_support, feature_test_support, feature_batch_support]

suite "Supported primitive type values":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "Bool parameter + Bool result",
        source: """
      function identity(Bool value) returns Bool {
        return value;
      }

      function main() returns Bool {
        return identity(true);
      }
    """,
        expected: "true"
      ),
      FeatureBatchCase(
        name: "Byte parameter + Byte result",
        source: """
      function identity(Byte value) returns Byte {
        return value;
      }

      function main() returns Byte {
        return identity(127);
      }
    """,
        expected: "127"
      ),
      FeatureBatchCase(
        name: "Short parameter + Short result",
        source: """
      function identity(Short value) returns Short {
        return value;
      }

      function main() returns Short {
        return identity(300);
      }
    """,
        expected: "300"
      ),
      FeatureBatchCase(
        name: "Int parameter + Int result supports values beyond 32 bit",
        source: """
      function identity(Int value) returns Int {
        return value;
      }

      function main() returns Int {
        return identity(2147483648);
      }
    """,
        expected: "2147483648"
      ),
      FeatureBatchCase(
        name: "Float parameter + Float result uses ordinary decimal syntax",
        source: """
      function identity(Float value) returns Float {
        return value;
      }

      function main() returns Float {
        return identity(2.5);
      }
    """,
        expected: "2.5"
      ),
      FeatureBatchCase(
        name: "Char parameter + Char result preserves the code unit",
        source: """
      function identity(Char value) returns Char {
        return value;
      }

      function main() returns Char {
        return identity('A');
      }
    """,
        expected: "65"
      )
    ], "primitive_variants_test_1")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

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
    let output = runFeatureSource(source, "primitive_byte_zero")

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
