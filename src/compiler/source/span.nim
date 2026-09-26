## Defines source locations shared by every compiler phase. Example: line 3, column 9 can later point an error at `salary`.

type
  SourceSpan* = object
    startOffset*: int
    endOffset*: int
    line*: int
    column*: int
