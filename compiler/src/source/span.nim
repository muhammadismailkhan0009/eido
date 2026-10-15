## Defines source locations shared by every compiler phase.
## Example: a span can identify `src/account.eido:3:9` and the exact source offsets for `salary`.

import source_unit

type
  SourceSpan* = object
    sourceId*: SourceId
    sourcePath*: string
    sourceOrigin*: SourceOrigin
    startOffset*: int
    endOffset*: int
    line*: int
    column*: int

## Creates a span from explicit source identity and coordinates.
## Example: a token at line 3, column 9 in account.eido retains that file identity through later compiler phases.
proc initSourceSpan*(
  sourceId: SourceId,
  sourcePath: string,
  startOffset, endOffset, line, column: int,
  sourceOrigin: SourceOrigin = soOrdinary
): SourceSpan =
  SourceSpan(
    sourceId: sourceId,
    sourcePath: sourcePath,
    sourceOrigin: sourceOrigin,
    startOffset: startOffset,
    endOffset: endOffset,
    line: line,
    column: column
  )

## Reports whether this source span belongs to compiler-injected runtime code.
proc isCompilerRuntime*(span: SourceSpan): bool =
  span.sourceOrigin == soCompilerRuntime

## Covers two spans that originate from the same source unit.
## Example: combining the spans of `a` and `5` produces the span for `a + 5`.
proc coverSpan*(first, last: SourceSpan): SourceSpan =
  initSourceSpan(
    first.sourceId,
    first.sourcePath,
    first.startOffset,
    last.endOffset,
    first.line,
    first.column,
    first.sourceOrigin
  )
