## Converts between UTF-8 byte offsets used by the compiler and UTF-16 LSP positions.

import std/json

## Returns the UTF-8 code-point width from one leading byte.
proc utf8Width(leading: char): int =
  let value = ord(leading)
  if value < 0x80: 1
  elif value < 0xE0: 2
  elif value < 0xF0: 3
  else: 4

## Returns the UTF-16 code-unit width represented by one UTF-8 leading byte.
proc utf16Width(leading: char): int =
  if ord(leading) >= 0xF0: 2 else: 1

## Converts a compiler byte offset into a zero-based LSP UTF-16 position.
proc lspPositionAt*(text: string, byteOffset: int): JsonNode =
  let bounded = max(0, min(byteOffset, text.len))
  var line = 0
  var lineStart = 0

  for index in 0 ..< bounded:
    if text[index] == '\n':
      inc line
      lineStart = index + 1

  var character = 0
  var index = lineStart
  while index < bounded:
    character += utf16Width(text[index])
    index += min(utf8Width(text[index]), bounded - index)

  %*{
    "line": line,
    "character": character
  }

## Converts a zero-based LSP UTF-16 position into a compiler UTF-8 byte offset.
proc byteOffsetAt*(text: string, targetLine, targetCharacter: int): int =
  var line = 0
  var index = 0

  while index < text.len and line < targetLine:
    if text[index] == '\n':
      inc line
    inc index

  if line != targetLine:
    return text.len

  var character = 0
  while index < text.len and text[index] != '\n':
    let units = utf16Width(text[index])
    if character + units > targetCharacter:
      break
    if character == targetCharacter:
      break

    character += units
    index += min(utf8Width(text[index]), text.len - index)

  index

## Converts one compiler byte span into an LSP range.
proc lspRange*(
  text: string,
  startOffset, endOffset: int
): JsonNode =
  %*{
    "start": lspPositionAt(text, startOffset),
    "end": lspPositionAt(text, max(endOffset, startOffset + 1))
  }
