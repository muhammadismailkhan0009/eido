## Emits representation-neutral class helpers plus Storage-backed managed support.
## Every ordinary class construction/field operation goes through these helpers.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../types/storage
import names
import type_emitter

## Finds one planned field by source name.
proc findFieldPlan(
  typePlan: CompileTimeTypeLayout,
  fieldSourceName: string
): CompileTimeFieldLayout =
  for fieldPlan in typePlan.fields:
    if fieldPlan.fieldName == fieldSourceName:
      return fieldPlan
  raise newException(
    ValueError,
    "backend invariant: missing managed field plan '" &
      fieldSourceName & "'"
  )

## Finds one type plan by class identity.
proc findTypePlan(
  plan: CompileTimeMemoryPlan,
  classSourceName: string
): CompileTimeTypeLayout =
  for typePlan in plan.types:
    if typePlan.className == classSourceName:
      return typePlan
  raise newException(
    ValueError,
    "backend invariant: missing managed type plan '" &
      classSourceName & "'"
  )

## Renders one managed class trace callback from selected strategy policy.
proc renderTraceProc(
  classDecl: hirDeclarations.HirClass,
  typePlan: CompileTimeTypeLayout
): string =
  let payloadType = classPayloadName(classDecl.sourceName)
  result.add "proc " & classTraceName(classDecl.sourceName) &
    "(payloadAddress: pointer) {.nimcall.} =\n"
  result.add "  let payload = cast[ptr " & payloadType &
    "](payloadAddress)\n"

  var traced = 0
  for field in classDecl.fields:
    let fieldPlan = typePlan.findFieldPlan(field.sourceName)
    if not fieldPlan.traced:
      continue
    result.add "  eidoGcMark(payload[]." &
      fieldName(field.sourceName) & ")\n"
    inc traced

  if traced == 0:
    result.add "  discard\n"
  result.add "\n"

## Renders one managed destroy callback that clears backend-managed field values.
proc renderDestroyProc(classDecl: hirDeclarations.HirClass): string =
  let payloadType = classPayloadName(classDecl.sourceName)
  result.add "proc " & classDestroyName(classDecl.sourceName) &
    "(payloadAddress: pointer) {.nimcall.} =\n"
  if classDecl.fields.len == 0:
    result.add "  discard\n\n"
  else:
    result.add "  cast[ptr " & payloadType &
      "](payloadAddress)[] = default(" & payloadType & ")\n\n"

## Renders blank allocation for either managed or bootstrap representation.
## Renders compile-time representation assertions for non-empty managed payloads.
proc renderLayoutAssertions(
  classDecl: hirDeclarations.HirClass
): string =
  if classDecl.fields.len == 0:
    return

  let sourceName = classDecl.sourceName
  let payloadType = classPayloadName(sourceName)
  let metadataPrefix = className(sourceName) & "_gc"
  result.add "static:\n"
  result.add "  doAssert int64(sizeof(" & payloadType & ")) == " &
    metadataPrefix & "_payload_size\n"
  result.add "  doAssert int64(alignof(" & payloadType & ")) == " &
    metadataPrefix & "_alignment\n\n"

## Renders blank allocation for either managed or bootstrap representation.
proc renderAllocateProc(
  classDecl: hirDeclarations.HirClass,
  plan: CompileTimeMemoryPlan
): string =
  let sourceName = classDecl.sourceName
  result.add "proc " & classAllocateName(sourceName) & "(): " &
    className(sourceName) & " =\n"

  if plan.hasManagedLayout(sourceName):
    let metadataPrefix = className(sourceName) & "_gc"
    result.add "  result = eidoGcAllocate(\n"
    result.add "    " & metadataPrefix & "_payload_size,\n"
    result.add "    " & metadataPrefix & "_alignment,\n"
    result.add "    " & classTraceName(sourceName) & ",\n"
    result.add "    " & classDestroyName(sourceName) & "\n"
    result.add "  )\n\n"
  else:
    result.add "  result = " & className(sourceName) & "()\n\n"

## Renders representation-neutral getters and setters for every source field.
proc renderFieldAccessors(
  classDecl: hirDeclarations.HirClass,
  plan: CompileTimeMemoryPlan
): string =
  let managed = plan.hasManagedLayout(classDecl.sourceName)

  for field in classDecl.fields:
    result.add "proc " & classFieldGetName(
      classDecl.sourceName,
      field.sourceName
    ) & "(source: " & className(classDecl.sourceName) & "): var " &
      renderType(field.typ) & " =\n"

    if managed:
      result.add "  eidoGcPayload[" &
        classPayloadName(classDecl.sourceName) &
        "](source)[]." & fieldName(field.sourceName) & "\n\n"
    else:
      result.add "  source." & fieldName(field.sourceName) & "\n\n"

    result.add "proc " & classFieldSetName(
      classDecl.sourceName,
      field.sourceName
    ) & "(source: " & className(classDecl.sourceName) &
      ", value: " & renderType(field.typ) & ") =\n"

    if managed:
      result.add "  eidoGcPayload[" &
        classPayloadName(classDecl.sourceName) &
        "](source)[]." & fieldName(field.sourceName) & " = value\n\n"
    else:
      result.add "  source." & fieldName(field.sourceName) & " = value\n\n"

## Renders backend-only invariant-depth helpers outside managed payload layout.
proc renderInvariantDepthSupport(
  classDecl: hirDeclarations.HirClass,
  plan: CompileTimeMemoryPlan
): string =
  if classDecl.invariants.len == 0:
    return

  let sourceType = className(classDecl.sourceName)
  let managed = plan.hasManagedLayout(classDecl.sourceName)
  let depthField = invariantEvaluationDepthFieldName()

  result.add "proc " & classInvariantEnterName(classDecl.sourceName) &
    "(source: " & sourceType & ") =\n"
  if managed:
    result.add "  eidoGcInvariantDepth(source) += 1\n\n"
  else:
    result.add "  source." & depthField & " += 1\n\n"

  result.add "proc " & classInvariantLeaveName(classDecl.sourceName) &
    "(source: " & sourceType & ") =\n"
  if managed:
    result.add "  eidoGcInvariantDepth(source) -= 1\n\n"
  else:
    result.add "  source." & depthField & " -= 1\n\n"

  result.add "proc " & classInvariantClearName(classDecl.sourceName) &
    "(source: " & sourceType & "): bool =\n"
  if managed:
    result.add "  eidoGcInvariantDepth(source) == 0\n\n"
  else:
    result.add "  source." & depthField & " == 0\n\n"

## Renders the field-complete constructor helper for one class.
proc renderConstructorProc(
  classDecl: hirDeclarations.HirClass
): string =
  let sourceName = classDecl.sourceName
  result.add "proc " & classConstructorName(sourceName) & "("
  for index, field in classDecl.fields:
    if index > 0:
      result.add ", "
    result.add "arg_" & fieldName(field.sourceName) & ": " &
      renderType(field.typ)
  result.add "): " & className(sourceName) & " =\n"
  result.add "  result = " & classAllocateName(sourceName) & "()\n"
  for field in classDecl.fields:
    result.add "  " & classFieldSetName(
      sourceName,
      field.sourceName
    ) & "(result, arg_" & fieldName(field.sourceName) & ")\n"
  if classDecl.fields.len == 0:
    result.add "  discard\n"
  result.add "\n"

## Renders all class runtime support selected by one compilation memory plan.
proc renderClassRuntimeSupport*(
  classes: seq[hirDeclarations.HirClass],
  plan: CompileTimeMemoryPlan
): string =
  for classDecl in classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      continue

    if plan.hasManagedLayout(classDecl.sourceName):
      let typePlan = plan.findTypePlan(classDecl.sourceName)
      result.add renderTraceProc(classDecl, typePlan)
      result.add renderDestroyProc(classDecl)
      result.add renderLayoutAssertions(classDecl)

    result.add renderAllocateProc(classDecl, plan)
    result.add renderFieldAccessors(classDecl, plan)
    result.add renderInvariantDepthSupport(classDecl, plan)
    result.add renderConstructorProc(classDecl)
