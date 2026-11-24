## File-level declaration organization. Module-wide name resolution remains independent.
import std/algorithm
import ../../diagnostics/errors
import ../../source/span
import ../ast/program

type
  DeclarationKind = enum
    dkFunction, dkMain, dkOther
  Declaration = tuple[span: SourceSpan, kind: DeclarationKind]

## Enforces mutually exclusive top-level file categories and reports the first conflicting declaration.
proc validateSourceStructure*(program: Program) =
  var declarations: seq[Declaration]
  for item in program.classes: declarations.add (item.span, dkOther)
  for item in program.interfaces: declarations.add (item.span, dkOther)
  for item in program.layouts: declarations.add (item.span, dkOther)
  for item in program.layoutConfigCalls: declarations.add (item.span, dkOther)
  for item in program.functions:
    declarations.add (item.span, (if item.name == "main": dkMain else: dkFunction))
  declarations.sort(proc(a, b: Declaration): int = cmp(a.span.startOffset, b.span.startOffset))
  if declarations.len < 2: return
  let first = declarations[0].kind
  for i in 1 ..< declarations.len:
    let current = declarations[i]
    if first == dkMain or current.kind == dkMain:
      failAt(current.span, "source file containing main must contain no other top-level declarations")
    if first == dkOther or current.kind == dkOther:
      failAt(current.span, "source file may contain only one non-function top-level declaration and no standalone functions")
