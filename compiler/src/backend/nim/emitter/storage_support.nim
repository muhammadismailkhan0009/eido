## Renders backend glue only for compiler-backed Storage operations.
## Normal typed Storage<T> behavior is implemented in SDK Eido source.

import ../../../hir/declarations as hirDeclarations
import ../../../compile_time/model
import ../../../types/[function_result, model, storage]
import names
import type_emitter

## Returns the concrete element type carried by one Storage<T> class.
proc storageElementType*(classDecl: hirDeclarations.HirClass): EidoType =
  if not isConcreteStorageTypeName(classDecl.sourceName):
    raise newException(ValueError, "backend invariant: expected Storage<T> class")

  for methodDecl in classDecl.methods:
    if methodDecl.sourceName == "read" and methodDecl.result.kind == frSingle:
      return methodDecl.result.typ

  raise newException(ValueError, "backend invariant: Storage<T> has no typed read method")

## Reports whether one concrete Storage specialization declares a native method.
proc hasNativeMethod(classDecl: hirDeclarations.HirClass, name: string): bool =
  for methodDecl in classDecl.methods:
    if methodDecl.isNative and methodDecl.sourceName == name:
      return true
  false

## Renders one native Storage method only when the analyzed specialization declares it.
proc renderStorageClassSupport(
  classDecl: hirDeclarations.HirClass,
  metadata: CompileTimeMemoryMetadata
): string =
  let owner = classDecl.sourceName
  let storageType = className(owner)
  let rawType = className(rawStorageTypeName(owner))
  let element = storageElementType(classDecl)
  let elementType = renderType(element)
  let inlineClass = element.kind == etkClass and
    not isConcreteStorageTypeName(element.className) and
    metadata.hasObjectLayout(element.className)
  let physicalType =
    if inlineClass: classPayloadName(element.className) else: elementType

  template methodNameFor(name: string): string = storageMethodName(owner, name)

  if classDecl.hasNativeMethod("allocate"):
    result.add "proc " & methodNameFor("allocate") & "(allocations: int64): " & storageType & " =\n"
    result.add "  eidoStorageAllocateRaw(allocations, int64(1))\n\n"

  if classDecl.hasNativeMethod("allocateRaw"):
    result.add "proc " & methodNameFor("allocateRaw") &
      "(allocations: int64, bytesPerAllocation: int64): " & storageType & " =\n"
    result.add "  eidoStorageAllocateRaw(allocations, bytesPerAllocation)\n\n"

  if classDecl.hasNativeMethod("fromAddress"):
    result.add "proc " & methodNameFor("fromAddress") &
      "(startingAddress: int64, allocations: int64, bytesPerAllocation: int64): " & storageType & " =\n"
    result.add "  eidoStorageFromAddress(startingAddress, allocations, bytesPerAllocation)\n\n"

  if classDecl.hasNativeMethod("borrowAddress"):
    result.add "proc " & methodNameFor("borrowAddress") &
      "(startingAddress: int64, allocations: int64, bytesPerAllocation: int64): " & storageType & " =\n"
    result.add "  eidoStorageBorrowAddress(startingAddress, allocations, bytesPerAllocation)\n\n"

  if classDecl.hasNativeMethod("view"):
    result.add "proc " & methodNameFor("view") & "(storage: " & rawType &
      ", start: int64): " & storageType & " =\n"
    result.add "  eidoStorageSlice[int8](storage, start, storage.capacity - start)\n\n"

  if classDecl.hasNativeMethod("viewAt"):
    result.add "proc " & methodNameFor("viewAt") & "(storage: " & rawType &
      ", byteOffset: int64): " & storageType & " =\n"
    result.add "  eidoStorageRawViewAt(storage, byteOffset)\n\n"

  if classDecl.hasNativeMethod("slice"):
    result.add "proc " & methodNameFor("slice") & "(storage: " & storageType &
      ", start: int64, count: int64): " & storageType & " =\n"
    result.add "  eidoStorageSlice[" & physicalType & "](storage, start, count)\n\n"

  if classDecl.hasNativeMethod("capacity"):
    result.add "proc " & methodNameFor("capacity") & "(storage: " & storageType & "): int64 =\n"
    result.add "  eidoStorageCapacity[" & physicalType & "](storage)\n\n"

  if classDecl.hasNativeMethod("address"):
    result.add "proc " & methodNameFor("address") & "(storage: " & storageType & "): int64 =\n"
    result.add "  eidoStorageAddress[" & physicalType & "](storage)\n\n"

  if classDecl.hasNativeMethod("read"):
    result.add "proc " & methodNameFor("read") & "(storage: " & storageType &
      ", index: int64): " & elementType & " =\n"
    if inlineClass:
      result.add "  " & elementType & "(eidoStorageSlotIdentity(storage, index))\n\n"
    else:
      result.add "  eidoStorageRead[" & physicalType & "](storage, index)\n\n"

  if classDecl.hasNativeMethod("write"):
    result.add "proc " & methodNameFor("write") & "(storage: " & storageType &
      ", index: int64, value: " & elementType & ") =\n"
    if inlineClass:
      result.add "  if value == int64(0):\n"
      result.add "    raise newException(ValueError, \"cannot write absent class into inline Storage\")\n"
      result.add "  eidoStorageWrite[" & physicalType &
        "](storage, index, cast[ptr " & physicalType & "](uint(value))[])\n\n"
    else:
      result.add "  eidoStorageWrite[" & physicalType & "](storage, index, value)\n\n"

  if classDecl.hasNativeMethod("release"):
    result.add "proc " & methodNameFor("release") & "(storage: var " & storageType & ") =\n"
    result.add "  eidoStorageRelease[" & physicalType & "](storage)\n\n"

  if classDecl.hasNativeMethod("size"):
    result.add "proc " & methodNameFor("size") & "(): int64 =\n"
    result.add "  eidoStorageSize[" & physicalType & "]()\n\n"

  if classDecl.hasNativeMethod("alignment"):
    result.add "proc " & methodNameFor("alignment") & "(): int64 =\n"
    result.add "  eidoStorageAlignment[" & physicalType & "]()\n\n"

  if classDecl.hasNativeMethod(StorageInternalFromRaw):
    result.add "proc " & methodNameFor(StorageInternalFromRaw) & "(storage: " & rawType &
      "): " & storageType & " =\n"
    result.add "  eidoStorageFromRaw[" & physicalType & "](storage)\n\n"

  if classDecl.hasNativeMethod(StorageInternalRaw):
    result.add "proc " & methodNameFor(StorageInternalRaw) & "(storage: " & storageType &
      "): " & rawType & " =\n"
    result.add "  eidoStorageRaw[" & physicalType & "](storage)\n\n"

  if classDecl.hasNativeMethod(StorageInternalRead):
    result.add "proc " & methodNameFor(StorageInternalRead) & "(storage: " & storageType &
      ", index: int64): " & elementType & " =\n"
    if inlineClass:
      result.add "  " & elementType & "(eidoStorageSlotIdentity(storage, index))\n\n"
    else:
      result.add "  eidoStorageRead[" & physicalType & "](storage, index)\n\n"

  if classDecl.hasNativeMethod(StorageInternalWrite):
    result.add "proc " & methodNameFor(StorageInternalWrite) & "(storage: " & storageType &
      ", index: int64, value: " & elementType & ") =\n"
    if inlineClass:
      result.add "  if value == int64(0):\n"
      result.add "    raise newException(ValueError, \"cannot write absent class into inline Storage\")\n"
      result.add "  eidoStorageWrite[" & physicalType &
        "](storage, index, cast[ptr " & physicalType & "](uint(value))[])\n\n"
    else:
      result.add "  eidoStorageWrite[" & physicalType & "](storage, index, value)\n\n"

## Renders compiler-backed glue for every concrete Storage type used by the program.
proc renderStorageSupport*(
  classes: seq[hirDeclarations.HirClass],
  metadata: CompileTimeMemoryMetadata = CompileTimeMemoryMetadata()
): string =
  for classDecl in classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      result.add renderStorageClassSupport(classDecl, metadata)

## Emits helpers that initialize inline Storage<Class> elements without
## allocating a temporary object through the selected memory policy.
proc renderInlineStorageWrites*(
  classes: seq[hirDeclarations.HirClass],
  metadata: CompileTimeMemoryMetadata,
  copySupport: bool
): string =
  for storageDecl in classes:
    if not isConcreteStorageTypeName(storageDecl.sourceName) or
        isRawStorageTypeName(storageDecl.sourceName):
      continue
    let element = storageElementType(storageDecl)
    if element.kind != etkClass or
        not metadata.hasObjectLayout(element.className):
      continue

    var found = false
    var objectDecl: hirDeclarations.HirClass
    for candidate in classes:
      if candidate.sourceName == element.className:
        objectDecl = candidate
        found = true
        break
    if not found:
      raise newException(ValueError, "missing Storage class payload: " & element.className)

    let storageType = className(storageDecl.sourceName)
    let identityType = renderType(element)
    let constructSink = storageMethodName(storageDecl.sourceName, "writeConstruct")
    let copySink = storageMethodName(storageDecl.sourceName, "writeCopy")

    result.add "proc " & constructSink & "(storage: " & storageType &
      ", index: int64"
    for field in objectDecl.fields:
      result.add ", arg_" & fieldName(field.sourceName) & ": " &
        renderType(field.typ)
    result.add ") =\n"
    result.add "  let identity = " & identityType &
      "(eidoStorageSlotIdentity(storage, index))\n"
    result.add "  " & classConstructAtName(element.className) & "(identity"
    for field in objectDecl.fields:
      result.add ", arg_" & fieldName(field.sourceName)
    result.add ")\n"
    if objectDecl.invariants.len > 0:
      result.add "  discard " & classInvariantName(element.className) &
        "(identity)\n"
    result.add "\n"

    if copySupport:
      result.add "proc " & copySink & "(storage: " & storageType &
        ", index: int64, source: " & identityType & ") =\n"
      result.add "  let identity = " & identityType &
        "(eidoStorageSlotIdentity(storage, index))\n"
      result.add "  " & classCopyIntoName(element.className) &
        "(identity, source)\n\n"
