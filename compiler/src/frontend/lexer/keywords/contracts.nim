## Classifies Design by Contract declaration keywords.
## Example: `require` becomes `tkRequire`, while an ordinary identifier remains unchanged.

## Maps one contract keyword to its token kind.
proc contractKeywordKind(text: string): TokenKind =
  case text
  of "require": tkRequire
  of "ensure": tkEnsure
  of "invariant": tkInvariant
  else: tkIdentifier
