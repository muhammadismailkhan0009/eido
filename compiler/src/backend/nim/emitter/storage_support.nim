## Renders thin specialization glue from compiler-owned Storage<T> methods
## to the ordinary Nim implementation in the eido_storage runtime module.

import ../../../hir/declarations as hirDeclarations
import ../../../types/[function_result, model, storage]
import names
import type_emitter

## Returns the concrete element type carried by one synthetic Storage<T> class.
proc storageElementType*(classDecl: hirDeclarations.HirClass): EidoType =
  if not isConcreteStorageTypeName(classDecl.sourceName):
    raise newException(
      ValueError,
      "backend invariant: expected Storage<T> class"
    )

  for methodDecl in classDecl.methods:
    if methodDecl.sourceName == "read" and
        methodDecl.result.kind == frSingle:
      return methodDecl.result.typ

  raise newException(
    ValueError,
    "backend invariant: Storage<T> has no typed read method"
  )

## Renders one concrete Storage<T> API specialization as runtime calls.
proc renderStorageClassSupport(
  classDecl: hirDeclarations.HirClass
): string =
  let storageType = className(classDecl.sourceName)
  let byteStorageType = className("Storage<Byte>")
  let elementType = renderType(storageElementType(classDecl))
  let allocateName = storageMethodName(classDecl.sourceName, "allocate")
  let viewName = storageMethodName(classDecl.sourceName, "view")
  let sliceName = storageMethodName(classDecl.sourceName, "slice")
  let capacityName = storageMethodName(classDecl.sourceName, "capacity")
  let readName = storageMethodName(classDecl.sourceName, "read")
  let writeName = storageMethodName(classDecl.sourceName, "write")
  let releaseName = storageMethodName(classDecl.sourceName, "release")

  result.add "proc " & allocateName & "(capacity: int64, initialValue: " &
    elementType & "): " & storageType & " =\n"
  result.add "  eidoStorageAllocate[" & elementType &
    "](capacity, initialValue)\n\n"

  result.add "proc " & viewName & "(storage: " & byteStorageType &
    ", byteOffset: int64, count: int64): " & storageType & " =\n"
  result.add "  eidoStorageView[" & elementType &
    "](storage, byteOffset, count)\n\n"

  result.add "proc " & sliceName & "(storage: " & storageType &
    ", start: int64, count: int64): " & storageType & " =\n"
  result.add "  eidoStorageSlice[" & elementType &
    "](storage, start, count)\n\n"
  result.add "proc " & capacityName & "(storage: " & storageType &
    "): int64 =\n"
  result.add "  eidoStorageCapacity[" & elementType & "](storage)\n\n"

  result.add "proc " & readName & "(storage: " & storageType &
    ", index: int64): " & elementType & " =\n"
  result.add "  eidoStorageRead[" & elementType & "](storage, index)\n\n"

  result.add "proc " & writeName & "(storage: " & storageType &
    ", index: int64, value: " & elementType & ") =\n"
  result.add "  eidoStorageWrite[" & elementType &
    "](storage, index, value)\n\n"

  result.add "proc " & releaseName & "(storage: var " & storageType & ") =\n"
  result.add "  eidoStorageRelease[" & elementType & "](storage)\n\n"

## Renders specialization glue for every concrete Storage<T> used by the program.
proc renderStorageSupport*(classes: seq[hirDeclarations.HirClass]): string =
  for classDecl in classes:
    if isConcreteStorageTypeName(classDecl.sourceName):
      result.add renderStorageClassSupport(classDecl)
