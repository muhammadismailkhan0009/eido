## Classifies the class declaration keyword.
## Example: `class` becomes `tkClass`, while `classify` remains an identifier.
proc classKeywordKind*(text: string): TokenKind =
  case text
  of "class": tkClass
  else: tkIdentifier
