## Registers layout declarations without applying them to physical memory.
## Layout bodies will be analyzed/executed by a future Eido compile-time phase.

import std/sets
import ../../diagnostics/errors
import ../../frontend/ast/declarations as astDeclarations
import ../../hir/declarations as hirDeclarations

proc analyzeLayouts*(
  layouts: seq[astDeclarations.LayoutDecl],
  classes: seq[hirDeclarations.HirClass]
): seq[hirDeclarations.HirLayout] =
  var knownClasses = initHashSet[string]()
  var names = initHashSet[string]()
  for classDecl in classes:
    knownClasses.incl classDecl.sourceName

  for layout in layouts:
    if layout.name in names:
      failAt(layout.span, "duplicate layout declaration '" & layout.name & "'")
    names.incl layout.name
    if layout.targetType.name notin knownClasses:
      failAt(
        layout.targetType.span,
        "layout '" & layout.name &
        "' must target a concrete class, got '" & layout.targetType.name & "'"
      )
    result.add hirDeclarations.HirLayout(
      span: layout.span,
      sourceName: layout.name,
      targetClass: layout.targetType.name,
      body: layout.body
    )
