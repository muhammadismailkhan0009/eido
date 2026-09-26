## Classifies identifier-shaped text as keywords, supported primitive type names, boolean literals, or ordinary identifiers.
## Example: `Float` becomes `tkPrimitiveType`, while removed `Double` stays an identifier.

import token

## Maps identifier text to its token kind.
## Example: `"true"` becomes `tkBoolean`, while `"Long"` stays `tkIdentifier`.
proc keywordKind*(text: string): TokenKind =
  case text
  of "function": tkFunction
  of "returns": tkReturns
  of "return": tkReturn
  of "var": tkVar
  of "not": tkNot
  of "and": tkAnd
  of "or": tkOr
  of "Bool", "Byte", "Short", "Int", "Float", "Char":
    tkPrimitiveType
  of "true", "false":
    tkBoolean
  else:
    tkIdentifier
