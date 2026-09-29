import std/unittest
import frontend/lexer/[keywords, token]

suite "Contract keywords":
  test "recognizes contract section keywords while result remains contextual":
    check keywordKind("require") == tkRequire
    check keywordKind("ensure") == tkEnsure
    check keywordKind("invariant") == tkInvariant
    check keywordKind("result") == tkIdentifier
