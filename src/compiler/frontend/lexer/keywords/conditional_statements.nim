## Classifies conditional-control-flow keywords.
## Example: `if` becomes `tkIf`, while `ifdef` remains an identifier.
proc conditionalKeywordKind*(text: string): TokenKind =
  case text
  of "if": tkIf
  of "else": tkElse
  else: tkIdentifier
