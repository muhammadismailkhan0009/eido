## Classifies identifier-shaped text as keywords, supported primitive type names, boolean literals, or ordinary identifiers.
## Example: `Float` becomes `tkPrimitiveType`, while removed `Double` stays an identifier.

import token
include keywords/boolean_operators
include keywords/conditional_statements

## Maps identifier text to its token kind.
## Example: `"true"` becomes `tkBoolean`, while `"Long"` stays `tkIdentifier`.
proc keywordKind*(text: string): TokenKind =
  let booleanOperator = booleanOperatorKeywordKind(text)
  if booleanOperator != tkIdentifier:
    return booleanOperator

  let conditionalKeyword = conditionalKeywordKind(text)
  if conditionalKeyword != tkIdentifier:
    return conditionalKeyword

  case text
  of "function": tkFunction
  of "returns": tkReturns
  of "return": tkReturn
  of "var": tkVar
  of "Bool", "Byte", "Short", "Int", "Float", "Char":
    tkPrimitiveType
  of "true", "false":
    tkBoolean
  else:
    tkIdentifier
