import std/[strutils, unittest]
import tooling/comment_service

suite "Tooling comment ranges":
  test "returns source comments without treating String content as comments":
    let source = """// heading
var url = "https://eido.dev//docs"; // trailing
"""

    let comments = lineCommentRanges(source)

    check comments.len == 2
    check source[
      comments[0].startOffset ..< comments[0].endOffset
    ] == "// heading"
    check source[
      comments[1].startOffset ..< comments[1].endOffset
    ] == "// trailing"

  test "includes a line comment that ends at end of file":
    let source = "var value = 1; // final"

    let comments = lineCommentRanges(source)

    check comments.len == 1
    check source[
      comments[0].startOffset ..< comments[0].endOffset
    ] == "// final"

  test "apostrophes inside comments remain ordinary comment text":
    let source = """// it's only a comment
var letter = 'A';
// arena's backing remains valid
var value = 1;
"""

    let comments = lineCommentRanges(source)

    check comments.len == 2
    check source[
      comments[0].startOffset ..< comments[0].endOffset
    ] == "// it's only a comment"
    check source[
      comments[1].startOffset ..< comments[1].endOffset
    ] == "// arena's backing remains valid"


  test "collects contiguous documentation comments before declarations":
    let source = """/// Public process operations.
/// Available to ordinary Eido programs.
class Process {
}
"""
    let declarationOffset = source.find("class Process")

    check documentationCommentBefore(source, declarationOffset) ==
      "Public process operations.\nAvailable to ordinary Eido programs."

  test "ordinary comments and blank lines break documentation attachment":
    let ordinary = """// implementation note
class Internal {
}
"""
    check documentationCommentBefore(
      ordinary,
      ordinary.find("class Internal")
    ) == ""

    let separated = """/// Not attached.

class Separate {
}
"""
    check documentationCommentBefore(
      separated,
      separated.find("class Separate")
    ) == ""
