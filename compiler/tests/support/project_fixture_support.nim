## Builds valid multi-source compiler projects from compact test fixture text.
## Production compilation still enforces file-level declaration organization.

import std/algorithm
import frontend/ast/program
import frontend/lexer/scanner
import frontend/parser/program_parser
import project/model
import source/source_unit
import stdlib/builtin_sources

type
  FixtureDeclarationRange = tuple[startOffset, endOffset: int]

## Splits top-level declarations from one compact fixture into separate virtual files.
## Example: an interface, class, and main function become three SourceUnits.
proc fixtureProject*(
  source: string,
  target: ProjectTarget = ptExecutable
): EidoProject =
  let parsed = parseProgram(lexAll(source))
  var ranges: seq[FixtureDeclarationRange]

  for declaration in parsed.interfaces:
    ranges.add (
      startOffset: declaration.span.startOffset,
      endOffset: declaration.span.endOffset
    )
  for declaration in parsed.classes:
    ranges.add (
      startOffset: declaration.span.startOffset,
      endOffset: declaration.span.endOffset
    )
  for declaration in parsed.functions:
    ranges.add (
      startOffset: declaration.span.startOffset,
      endOffset: declaration.span.endOffset
    )
  for declaration in parsed.layouts:
    ranges.add (
      startOffset: declaration.span.startOffset,
      endOffset: declaration.span.endOffset
    )
  for selection in parsed.layoutConfigCalls:
    ranges.add (
      startOffset: selection.span.startOffset,
      endOffset: selection.span.endOffset
    )

  ranges.sort(proc (
    left,
    right: FixtureDeclarationRange
  ): int = cmp(left.startOffset, right.startOffset))

  var sources: seq[SourceUnit]
  for index, declarationRange in ranges:
    sources.add initSourceUnit(
      index,
      "fixture_" & $index & ".eido",
      source[declarationRange.startOffset ..< declarationRange.endOffset]
    )

  # Standalone feature fixtures still exercise the real SDK Eido Storage<T>
  # template instead of a compiler-synthesized typed compatibility surface.
  sources.add initSourceUnit(
    sources.len,
    BuiltinStorageSourcePath,
    BuiltinStorageSource,
    BuiltinStorageModuleName, embeddedSdk = true
  )

  sources.add initSourceUnit(
    sources.len,
    BuiltinAlignmentSourcePath,
    BuiltinAlignmentSource,
    BuiltinStorageModuleName, embeddedSdk = true
  )

  sources.add initSourceUnit(
    sources.len,
    BuiltinAlignedHeapBackingSourcePath,
    BuiltinAlignedHeapBackingSource,
    BuiltinStorageModuleName, embeddedSdk = true
  )

  initProject(target, sources)
