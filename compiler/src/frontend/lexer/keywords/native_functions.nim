## Classifies the native-function declaration keyword.
## Example: `native function platformArgumentCount() returns Int;` begins with tkNative.

## Maps the native declaration keyword while leaving other text untouched.
## Example: "native" becomes tkNative while "nativeValue" remains an identifier.
proc nativeFunctionKeywordKind(text: string): TokenKind =
  if text == "native": tkNative else: tkIdentifier
