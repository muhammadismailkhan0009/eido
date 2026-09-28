## Classifies interface architecture keywords.
## Interfaces are explicit behavioral contracts; classes explicitly implement them.

## Returns the token kind for interface-related words.
proc interfaceKeywordKind(text: string): TokenKind =
  case text
  of "interface": tkInterface
  of "implements": tkImplements
  of "extends": tkExtends
  else: tkIdentifier
