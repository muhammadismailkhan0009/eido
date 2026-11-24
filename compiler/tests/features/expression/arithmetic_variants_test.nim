import std/unittest
import support/feature_batch_support

suite "Binary arithmetic operations":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "Int addition",
        source: "function main() returns Int { return 10 + 5; }",
        expected: "15"
      ),
      FeatureBatchCase(
        name: "Int subtraction",
        source: "function main() returns Int { return 10 - 3; }",
        expected: "7"
      ),
      FeatureBatchCase(
        name: "Int multiplication",
        source: "function main() returns Int { return 6 * 7; }",
        expected: "42"
      ),
      FeatureBatchCase(
        name: "Int division",
        source: "function main() returns Int { return 10 / 3; }",
        expected: "3"
      ),
      FeatureBatchCase(
        name: "Float addition",
        source: "function main() returns Float { return 1.5 + 2.5; }",
        expected: "4.0"
      ),
      FeatureBatchCase(
        name: "Float division",
        source: "function main() returns Float { return 5.0 / 2.0; }",
        expected: "2.5"
      )
    ], "arithmetic_variants_test_1")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "Binary operator precedence":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "multiplication has higher precedence than addition",
        source: "function main() returns Int { return 10 + 20 * 3; }",
        expected: "70"
      ),
      FeatureBatchCase(
        name: "division has higher precedence than addition",
        source: "function main() returns Int { return 10 + 20 / 5; }",
        expected: "14"
      ),
      FeatureBatchCase(
        name: "multiplication has higher precedence than subtraction",
        source: "function main() returns Int { return 20 - 3 * 4; }",
        expected: "8"
      )
    ], "arithmetic_variants_test_2")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "Equal-precedence binary associativity":
  test "successful Eido programs (batched)":
    let results = runFeatureBatch(@[
      FeatureBatchCase(
        name: "multiplication and division are evaluated left to right",
        source: "function main() returns Int { return 20 / 5 * 2; }",
        expected: "8"
      ),
      FeatureBatchCase(
        name: "addition and subtraction are evaluated left to right",
        source: "function main() returns Int { return 10 - 3 + 2; }",
        expected: "9"
      )
    ], "arithmetic_variants_test_3")
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected
