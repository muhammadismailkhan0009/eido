import std/unittest
import frontend/lexer/[keywords, token]

suite "Interface keywords":
  test "classifies interface architecture words":
    check keywordKind("interface") == tkInterface
    check keywordKind("implements") == tkImplements
    check keywordKind("extends") == tkExtends

  test "does not reserve similar ordinary identifiers":
    check keywordKind("implementation") == tkIdentifier
    check keywordKind("extension") == tkIdentifier
