## Classifies the for-loop keyword.
## Example: `for` becomes `tkFor`, while `format` remains an identifier.
proc forKeywordKind*(text: string): TokenKind =
  case text
  of "for": tkFor
  else: tkIdentifier
