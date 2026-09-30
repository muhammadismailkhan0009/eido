## Builds valid multi-source compiler projects from compact test fixture text.
## Production compilation still enforces one outermost class/interface per source file.

import std/algorithm
import frontend/ast/program
import frontend/lexer/scanner
import frontend/parser/program_parser
import project/model
import source/source_unit

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

  initProject(target, sources)
