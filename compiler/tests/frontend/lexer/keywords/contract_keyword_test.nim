import std/unittest
import frontend/lexer/[keywords, token]

suite "Contract keywords":
  test "recognizes require ensure invariant and result":
    check keywordKind("require") == tkRequire
    check keywordKind("ensure") == tkEnsure
    check keywordKind("invariant") == tkInvariant
    check keywordKind("result") == tkResult
