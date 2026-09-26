## Classifies the while control-flow keyword.
## Example: `while` becomes `tkWhile`, while `meanwhile` remains an identifier.
proc whileKeywordKind*(text: string): TokenKind =
  case text
  of "while": tkWhile
  else: tkIdentifier
