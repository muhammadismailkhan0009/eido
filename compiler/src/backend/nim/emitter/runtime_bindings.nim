## Resolves Eido-selected generic program-event bindings to ordinary Eido methods.
## The compiler does not choose memory policy or runtime implementation method names.

import ../../../compile_time/instrumentation_model
import ../../../hir/program as hirProgram
import ../../../source/span
import names

type
  RuntimeBindings* = object
    bindingEnter*: string
    bindingWrite*: string
    bindingLeave*: string
    metadataType*: string
    metadataField*: string
    objectAcquire*: string
    temporaryEnter*: string
    temporaryLeave*: string
    statementBoundary*: string
    invariantEnter*: string
    invariantLeave*: string
    invariantClear*: string
    programExit*: string

## Resolves one policy-selected method name from compiler-runtime Eido sources.
proc resolveBinding(program: hirProgram.HirProgram, sourceName: string): string =
  if sourceName.len == 0:
    return ""
  var found = false
  for classDecl in program.classes:
    if not classDecl.span.isCompilerRuntime:
      continue
    for methodDecl in classDecl.methods:
      if methodDecl.sourceName != sourceName:
        continue
      if found:
        raise newException(ValueError, "duplicate compiler-runtime binding '" & sourceName & "'")
      found = true
      result = methodName(
        methodDecl.methodId,
        methodDecl.ownerType.className,
        methodDecl.sourceName
      )
  if not found:
    raise newException(ValueError, "missing compiler-runtime binding '" & sourceName & "'")

## Resolves the Eido-selected instrumentation plan against ordinary runtime methods.
proc bindRuntimeInstrumentation*(
  program: hirProgram.HirProgram,
  plan: CompileTimeInstrumentationPlan
): RuntimeBindings =
  RuntimeBindings(
    bindingEnter: program.resolveBinding(plan.bindingEnter),
    bindingWrite: program.resolveBinding(plan.bindingWrite),
    bindingLeave: program.resolveBinding(plan.bindingLeave),
    metadataType: program.resolveBinding(plan.metadataType),
    metadataField: program.resolveBinding(plan.metadataField),
    objectAcquire: program.resolveBinding(plan.objectAcquire),
    temporaryEnter: program.resolveBinding(plan.temporaryEnter),
    temporaryLeave: program.resolveBinding(plan.temporaryLeave),
    statementBoundary: program.resolveBinding(plan.statementBoundary),
    invariantEnter: program.resolveBinding(plan.invariantEnter),
    invariantLeave: program.resolveBinding(plan.invariantLeave),
    invariantClear: program.resolveBinding(plan.invariantClear),
    programExit: program.resolveBinding(plan.programExit)
  )
