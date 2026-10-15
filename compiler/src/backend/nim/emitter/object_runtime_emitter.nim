## Emits representation-neutral class construction and field helpers.
## Construction semantics are compiler-owned; storage acquisition is delegated to Eido memory policy.

import ../../../compile_time/model
import ../../../hir/declarations as hirDeclarations
import ../../../types/storage
import names
import type_emitter
import runtime_bindings

## Renders compile-time representation assertions for non-empty object payloads.
proc renderLayoutAssertions(classDecl: hirDeclarations.HirClass): string =
  if classDecl.fields.len == 0:
    return

  let sourceName = classDecl.sourceName
  let payloadType = classPayloadName(sourceName)
  let metadataPrefix = className(sourceName) & "_memory"
  result.add "static:\n"
  result.add "  doAssert int64(sizeof(" & payloadType & ")) == " &
    metadataPrefix & "_payload_size\n"
  result.add "  doAssert int64(alignof(" & payloadType & ")) == " &
    metadataPrefix & "_alignment\n\n"

## Renders storage acquisition for one class construction without selecting policy in the compiler.
proc renderAllocateProc(
  classDecl: hirDeclarations.HirClass,
  metadata: CompileTimeMemoryMetadata,
  runtimeBindings: RuntimeBindings
): string =
  let sourceName = classDecl.sourceName
  result.add "proc " & classAllocateName(sourceName) & "(): " &
    className(sourceName) & " =\n"

  if metadata.hasObjectLayout(sourceName):
    if runtimeBindings.objectAcquire.len == 0:
      raise newException(
        ValueError,
        "runtime policy did not bind object-construction storage acquisition"
      )
    let metadataPrefix = className(sourceName) & "_memory"
    result.add "  result = " & runtimeBindings.objectAcquire & "(\n"
    result.add "    " & metadataPrefix & "_payload_size,\n"
    result.add "    " & metadataPrefix & "_alignment,\n"
    result.add "    " & classMemoryTypeIdName(sourceName) & "\n"
    result.add "  )\n\n"
  else:
    result.add "  result = " & className(sourceName) & "()\n\n"

## Renders representation-neutral getters and setters for every source field.
proc renderFieldAccessors(
  classDecl: hirDeclarations.HirClass,
  metadata: CompileTimeMemoryMetadata,
  runtimeBindings: RuntimeBindings
): string =
  let runtimeBacked = metadata.hasObjectLayout(classDecl.sourceName)

  for field in classDecl.fields:
    result.add "proc " & classFieldGetName(
      classDecl.sourceName,
      field.sourceName
    ) & "(source: " & className(classDecl.sourceName) & "): var " &
      renderType(field.typ) & " =\n"

    if runtimeBacked:
      result.add "  eidoMemoryPayloadAt(" & classPayloadName(classDecl.sourceName) &
        ", source)[]." & fieldName(field.sourceName) & "\n\n"
    else:
      result.add "  source." & fieldName(field.sourceName) & "\n\n"

    result.add "proc " & classFieldSetName(
      classDecl.sourceName,
      field.sourceName
    ) & "(source: " & className(classDecl.sourceName) &
      ", value: " & renderType(field.typ) & ") =\n"

    if runtimeBacked:
      result.add "  eidoMemoryPayloadAt(" & classPayloadName(classDecl.sourceName) &
        ", source)[]." & fieldName(field.sourceName) & " = value\n\n"
    else:
      result.add "  source." & fieldName(field.sourceName) & " = value\n\n"

## Renders backend invariant-depth helpers through the generic object runtime boundary.
proc renderInvariantDepthSupport(
  classDecl: hirDeclarations.HirClass,
  metadata: CompileTimeMemoryMetadata,
  runtimeBindings: RuntimeBindings
): string =
  if classDecl.invariants.len == 0:
    return

  let sourceType = className(classDecl.sourceName)
  let runtimeBacked = metadata.hasObjectLayout(classDecl.sourceName)
  let depthField = invariantEvaluationDepthFieldName()
  if runtimeBacked and (
      runtimeBindings.invariantEnter.len == 0 or
      runtimeBindings.invariantLeave.len == 0 or
      runtimeBindings.invariantClear.len == 0
  ):
    raise newException(
      ValueError,
      "runtime policy must bind invariant lifecycle events for classes with invariants"
    )

  result.add "proc " & classInvariantEnterName(classDecl.sourceName) &
    "(source: " & sourceType & ") =\n"
  if runtimeBacked:
    result.add "  " & runtimeBindings.invariantEnter & "(source)\n\n"
  else:
    result.add "  source." & depthField & " += 1\n\n"

  result.add "proc " & classInvariantLeaveName(classDecl.sourceName) &
    "(source: " & sourceType & ") =\n"
  if runtimeBacked:
    result.add "  " & runtimeBindings.invariantLeave & "(source)\n\n"
  else:
    result.add "  source." & depthField & " -= 1\n\n"

  result.add "proc " & classInvariantClearName(classDecl.sourceName) &
    "(source: " & sourceType & "): bool =\n"
  if runtimeBacked:
    result.add "  " & runtimeBindings.invariantClear & "(source)\n\n"
  else:
    result.add "  source." & depthField & " == 0\n\n"

## Renders the field-complete semantic constructor helper for one class.
proc renderConstructorProc(classDecl: hirDeclarations.HirClass): string =
  let sourceName = classDecl.sourceName
  result.add "proc " & classConstructorName(sourceName) & "("
  for index, field in classDecl.fields:
    if index > 0:
      result.add ", "
    result.add "arg_" & fieldName(field.sourceName) & ": " & renderType(field.typ)
  result.add "): " & className(sourceName) & " =\n"
  result.add "  result = " & classAllocateName(sourceName) & "()\n"
  for field in classDecl.fields:
    result.add "  " & classFieldSetName(sourceName, field.sourceName) &
      "(result, arg_" & fieldName(field.sourceName) & ")\n"
  if classDecl.fields.len == 0:
    result.add "  discard\n"
  result.add "\n"

## Renders all class runtime support from generic memory metadata.
proc renderClassRuntimeSupport*(
  classes: seq[hirDeclarations.HirClass],
  metadata: CompileTimeMemoryMetadata,
  runtimeBindings: RuntimeBindings
): string =
  for classDecl in classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      continue

    if metadata.hasObjectLayout(classDecl.sourceName):
      result.add renderLayoutAssertions(classDecl)

    result.add renderAllocateProc(classDecl, metadata, runtimeBindings)
    result.add renderFieldAccessors(classDecl, metadata, runtimeBindings)
    result.add renderInvariantDepthSupport(classDecl, metadata, runtimeBindings)
    result.add renderConstructorProc(classDecl)
