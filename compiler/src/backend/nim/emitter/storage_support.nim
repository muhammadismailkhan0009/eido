## Renders backend glue only for compiler-backed Storage operations.
## Normal typed Storage<T> behavior is implemented in SDK Eido source.

import ../../../hir/declarations as hirDeclarations
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
proc renderStorageClassSupport(classDecl: hirDeclarations.HirClass): string =
  let owner = classDecl.sourceName
  let storageType = className(owner)
  let rawType = className(rawStorageTypeName(owner))
  let element = storageElementType(classDecl)
  let elementType = renderType(element)

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
    result.add "  eidoStorageSlice[" & elementType & "](storage, start, count)\n\n"

  if classDecl.hasNativeMethod("capacity"):
    result.add "proc " & methodNameFor("capacity") & "(storage: " & storageType & "): int64 =\n"
    result.add "  eidoStorageCapacity[" & elementType & "](storage)\n\n"

  if classDecl.hasNativeMethod("address"):
    result.add "proc " & methodNameFor("address") & "(storage: " & storageType & "): int64 =\n"
    result.add "  eidoStorageAddress[" & elementType & "](storage)\n\n"

  if classDecl.hasNativeMethod("read"):
    result.add "proc " & methodNameFor("read") & "(storage: " & storageType &
      ", index: int64): " & elementType & " =\n"
    result.add "  eidoStorageRead[" & elementType & "](storage, index)\n\n"

  if classDecl.hasNativeMethod("write"):
    result.add "proc " & methodNameFor("write") & "(storage: " & storageType &
      ", index: int64, value: " & elementType & ") =\n"
    result.add "  eidoStorageWrite[" & elementType & "](storage, index, value)\n\n"

  if classDecl.hasNativeMethod("release"):
    result.add "proc " & methodNameFor("release") & "(storage: var " & storageType & ") =\n"
    result.add "  eidoStorageRelease[" & elementType & "](storage)\n\n"

  if classDecl.hasNativeMethod("size"):
    result.add "proc " & methodNameFor("size") & "(): int64 =\n"
    result.add "  eidoStorageSize[" & elementType & "]()\n\n"

  if classDecl.hasNativeMethod("alignment"):
    result.add "proc " & methodNameFor("alignment") & "(): int64 =\n"
    result.add "  eidoStorageAlignment[" & elementType & "]()\n\n"

  if classDecl.hasNativeMethod(StorageInternalFromRaw):
    result.add "proc " & methodNameFor(StorageInternalFromRaw) & "(storage: " & rawType &
      "): " & storageType & " =\n"
    result.add "  eidoStorageFromRaw[" & elementType & "](storage)\n\n"

  if classDecl.hasNativeMethod(StorageInternalRaw):
    result.add "proc " & methodNameFor(StorageInternalRaw) & "(storage: " & storageType &
      "): " & rawType & " =\n"
    result.add "  eidoStorageRaw[" & elementType & "](storage)\n\n"

  if classDecl.hasNativeMethod(StorageInternalRead):
    result.add "proc " & methodNameFor(StorageInternalRead) & "(storage: " & storageType &
      ", index: int64): " & elementType & " =\n"
    result.add "  eidoStorageRead[" & elementType & "](storage, index)\n\n"

  if classDecl.hasNativeMethod(StorageInternalWrite):
    result.add "proc " & methodNameFor(StorageInternalWrite) & "(storage: " & storageType &
      ", index: int64, value: " & elementType & ") =\n"
    result.add "  eidoStorageWrite[" & elementType & "](storage, index, value)\n\n"

## Renders compiler-backed glue for every concrete Storage type used by the program.
proc renderStorageSupport*(classes: seq[hirDeclarations.HirClass]): string =
  for classDecl in classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      result.add renderStorageClassSupport(classDecl)
