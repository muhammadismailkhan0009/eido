## Classifies Boolean word operators while leaving unrelated identifiers unchanged.
## Example: `not` becomes `tkNot`, while `notice` remains `tkIdentifier`.
proc booleanOperatorKeywordKind*(text: string): TokenKind =
  case text
  of "not": tkNot
  of "and": tkAnd
  of "or": tkOr
  else: tkIdentifier
