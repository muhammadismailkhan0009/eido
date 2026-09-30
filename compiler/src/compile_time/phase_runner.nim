## Orchestrates compiler-standard Eido compile-time phases.
## No compile-time phase APIs are part of the ordinary Eido source surface.

import ../hir/program as hirProgram
import ../types/storage
import memory_layout_phase
import model

## Runs the currently registered compiler-standard Eido phases.
## Primitive-only programs have no managed object-layout work.
proc runStandardCompileTimePhases*(
  program: hirProgram.HirProgram
): CompileTimeMemoryPlan =
  for classDecl in program.classes:
    if not isConcreteStorageTypeName(classDecl.sourceName):
      return runMemoryLayoutPhase(program)

  CompileTimeMemoryPlan()
