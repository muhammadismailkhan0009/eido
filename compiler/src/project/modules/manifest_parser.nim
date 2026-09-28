## Parses Eido's schema-restricted YAML module manifests.
## The accepted syntax is ordinary YAML for the v0 schema: mappings, sequences, plain/quoted scalars, and small inline mappings.

import std/[strutils]
import ../../diagnostics/errors
import model

const TopLevelKeys = [
  "module", "sources", "children", "dependencies",
  "exports", "provides", "adopts"
]

## Documents the unquote module helper behavior.
proc unquote(value: string): string =
  result = value.strip()
  if result.len >= 2 and
      ((result[0] == '"' and result[^1] == '"') or
       (result[0] == '\'' and result[^1] == '\'')):
    result = result[1 .. ^2]

## Documents the contentBeforeComment module helper behavior.
proc contentBeforeComment(line: string): string =
  var singleQuoted = false
  var doubleQuoted = false
  for index, c in line:
    case c
    of '\'':
      if not doubleQuoted:
        singleQuoted = not singleQuoted
    of '"':
      if not singleQuoted:
        doubleQuoted = not doubleQuoted
    of '#':
      if not singleQuoted and not doubleQuoted:
        return line[0 ..< index]
    else:
      discard
  line

## Documents the indentation module helper behavior.
proc indentation(line: string): int =
  while result < line.len and line[result] == ' ':
    inc result
  if result < line.len and line[result] == '\t':
    return -1

## Documents the splitKeyValue module helper behavior.
proc splitKeyValue(
  text, path: string,
  lineNumber: int
): tuple[key, value: string] =
  let separator = text.find(':')
  if separator < 0:
    failAt(path, lineNumber, 1, "expected YAML mapping entry 'key: value'")

  result.key = text[0 ..< separator].strip()
  result.value = text[separator + 1 .. ^1].strip()
  if result.key.len == 0:
    failAt(path, lineNumber, 1, "module YAML mapping key cannot be empty")

## Documents the inlineMappingValue module helper behavior.
proc inlineMappingValue(
  value, expectedKey, path: string,
  lineNumber: int
): string =
  let stripped = value.strip()
  if not (stripped.startsWith("{") and stripped.endsWith("}")):
    failAt(path, lineNumber, 1, "expected inline YAML mapping")

  let body = stripped[1 .. ^2].strip()
  let pair = splitKeyValue(body, path, lineNumber)
  if pair.key != expectedKey:
    failAt(
      path, lineNumber, 1,
      "expected '" & expectedKey & "' in inline module mapping"
    )
  unquote(pair.value)

## Documents the addSequenceValue module helper behavior.
proc addSequenceValue(
  manifest: var ModuleManifest,
  section, value, path: string,
  lineNumber: int
) =
  let item = unquote(value)
  if item.len == 0:
    failAt(path, lineNumber, 1, "module YAML sequence item cannot be empty")

  case section
  of "sources": manifest.sources.add item
  of "dependencies": manifest.dependencies.add item
  of "exports": manifest.exports.add item
  of "adopts": manifest.adopts.add item
  else:
    failAt(
      path, lineNumber, 1,
      "section '" & section & "' does not accept YAML sequence items"
    )

## Documents the parseModuleManifest module helper behavior.
proc parseModuleManifest*(text, path: string): ModuleManifest =
  var section = ""
  var childIndex = -1
  var provideIndex = -1
  var baseIndent = -1

  for rawLine in text.splitLines():
    let withoutComment = contentBeforeComment(rawLine)
    if withoutComment.strip().len == 0:
      continue
    let candidate = indentation(withoutComment)
    if candidate < 0:
      failAt(path, 1, 1, "module YAML indentation must use spaces")
    if baseIndent < 0 or candidate < baseIndent:
      baseIndent = candidate

  if baseIndent < 0:
    baseIndent = 0

  var lineNumber = 0
  for rawLine in text.splitLines():
    inc lineNumber
    let withoutComment = contentBeforeComment(rawLine)
    if withoutComment.strip().len == 0:
      continue

    let absoluteIndent = indentation(withoutComment)
    let indent = absoluteIndent - baseIndent
    if indent < 0 or indent mod 2 != 0:
      failAt(path, lineNumber, 1, "module YAML indentation must use spaces in multiples of two")

    let body = withoutComment[absoluteIndent .. ^1].strip()

    if indent == 0:
      childIndex = -1
      provideIndex = -1
      let pair = splitKeyValue(body, path, lineNumber)
      if pair.key notin TopLevelKeys:
        failAt(path, lineNumber, 1, "unknown module YAML key '" & pair.key & "'")

      section = pair.key
      if pair.key == "module":
        result.name = unquote(pair.value)
        section = ""
        if result.name.len == 0:
          failAt(path, lineNumber, 1, "module name cannot be empty")
      elif pair.value.len > 0:
        case pair.key
        of "sources", "dependencies", "exports", "adopts":
          if pair.value != "[]":
            failAt(path, lineNumber, 1, "'" & pair.key & "' must be a YAML sequence")
        of "children", "provides":
          if pair.value != "{}" and pair.value != "[]":
            failAt(path, lineNumber, 1, "'" & pair.key & "' must be a YAML mapping")
        else:
          discard
      continue

    if section.len == 0:
      failAt(path, lineNumber, 1, "unexpected nested YAML entry")

    if indent == 2 and body.startsWith("- "):
      result.addSequenceValue(section, body[2 .. ^1], path, lineNumber)
      continue

    if section == "children":
      if indent == 2:
        let pair = splitKeyValue(body, path, lineNumber)
        result.children.add ModuleChildManifest(name: pair.key)
        childIndex = result.children.high
        if pair.value.len > 0:
          result.children[childIndex].path =
            inlineMappingValue(pair.value, "path", path, lineNumber)
        continue

      if indent == 4 and childIndex >= 0:
        let pair = splitKeyValue(body, path, lineNumber)
        if pair.key != "path":
          failAt(path, lineNumber, 1, "child module accepts only a 'path' property")
        result.children[childIndex].path = unquote(pair.value)
        continue

    if section == "provides":
      if indent == 2:
        let pair = splitKeyValue(body, path, lineNumber)
        result.provides.add ModuleProvideManifest(contract: pair.key)
        provideIndex = result.provides.high
        if pair.value.len > 0:
          result.provides[provideIndex].by =
            inlineMappingValue(pair.value, "by", path, lineNumber)
        continue

      if indent == 4 and provideIndex >= 0:
        let pair = splitKeyValue(body, path, lineNumber)
        if pair.key != "by":
          failAt(path, lineNumber, 1, "provided contract accepts only a 'by' property")
        result.provides[provideIndex].by = unquote(pair.value)
        continue

    failAt(path, lineNumber, 1, "unsupported module YAML structure in section '" & section & "'")

  if result.name.len == 0:
    failAt(path, 1, 1, "module.yaml must declare 'module:'")

  for child in result.children:
    if child.path.len == 0:
      failAt(path, 1, 1, "child module '" & child.name & "' must declare path")

  for provision in result.provides:
    if provision.by.len == 0:
      failAt(path, 1, 1, "provided contract '" & provision.contract & "' must declare by")
