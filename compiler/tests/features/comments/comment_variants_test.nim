import std/unittest
import support/feature_test_support

suite "Line comments":
  test "whole-line and trailing comments do not change program behavior":
    let source = """
      // Explain the program without affecting its tokens.
      function main() returns Int {
        var value = 12; // Keep a trailing note beside code.
        return value / 3; // A single slash still means division.
      }
    """

    check runFeatureSource(source, "line_comments") == "4"

  test "line comment may terminate at end of source":
    let source = """
      function main() returns Int {
        return 7;
      }
      // final comment"""

    check runFeatureSource(source, "line_comment_eof") == "7"
