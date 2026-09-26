## Classifies loop-control keywords.
## Example: `break` and `continue` become reserved tokens.
proc loopControlKeywordKind*(text: string): TokenKind =
  case text
  of "break": tkBreak
  of "continue": tkContinue
  else: tkIdentifier
