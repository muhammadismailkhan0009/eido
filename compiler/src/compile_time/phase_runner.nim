## Selects and runs compiler-standard Eido memory strategies.
## Strategy entrypoints are build-machine-only and never enter ordinary Eido source.

import ../diagnostics/errors
import ../hir/declarations as hirDeclarations
import ../hir/program as hirProgram
import ../pipeline/options
import ../types/[method_kind, storage]
import gc_memory_strategy
import model

## Reports whether one class declaration requires an instance/managed representation.
## Storage capabilities and stateless static API classes require no managed object identity.
proc requiresManagedRepresentation(
  classDecl: hirDeclarations.HirClass
): bool =
  if isConcreteStorageTypeName(classDecl.sourceName):
    return false
  if classDecl.fields.len > 0:
    return true
  for methodDecl in classDecl.methods:
    if methodDecl.kind == mkInstance:
      return true
  false

## Reports whether one analyzed program contains classes that require managed identity.
proc hasManagedClasses(program: hirProgram.HirProgram): bool =
  for classDecl in program.classes:
    if classDecl.requiresManagedRepresentation:
      return true
  false

## Rejects managed class declarations while the explicit manual object model is unfinished.
## Primitive/Storage-only and stateless static-API programs may already use manual memory safely.
proc validateManualStrategy(program: hirProgram.HirProgram) =
  for classDecl in program.classes:
    if classDecl.requiresManagedRepresentation:
      failAt(
        classDecl.span,
        "manual memory strategy does not support managed class declarations yet"
      )

## Runs the selected compiler-standard memory strategy.
## GC currently selects the precise mark-and-sweep planner; manual performs no managed planning.
proc runStandardCompileTimePhases*(
  program: hirProgram.HirProgram,
  strategy: MemoryStrategy = msGc
): CompileTimeMemoryPlan =
  case strategy
  of msGc:
    if program.hasManagedClasses:
      return runGcMemoryStrategy(program)
    CompileTimeMemoryPlan()
  of msManual:
    validateManualStrategy(program)
    CompileTimeMemoryPlan()
