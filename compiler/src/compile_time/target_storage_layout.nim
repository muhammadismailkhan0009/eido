## Supplies target-storage facts to compiler-standard compile-time Eido phases.
## The current Nim backend targets the compiler host; this module is the single place
## that must become target-parameterized when explicit cross-target builds are added.

import std/options
import ../types/[model, storage]
import ../../../stdlib/native/nim/eido_storage

type
  StorageLayout* = object
    size*: int64
    alignment*: int64

template requiredLayout(T: typedesc): StorageLayout =
  StorageLayout(size: int64(sizeof(T)), alignment: int64(alignof(T)))

template optionalLayout(T: typedesc): StorageLayout =
  StorageLayout(
    size: int64(sizeof(Option[T])),
    alignment: int64(alignof(Option[T]))
  )

## Returns the physical Storage representation of one semantic value type.
## Class and interface values are references; Storage<T> is its allocation-free descriptor.
proc storageLayoutOf*(typ: EidoType): StorageLayout =
  let optional = typ.isOptional

  case typ.kind
  of etkPrimitive:
    case typ.primitive
    of ptBool:
      if optional: optionalLayout(bool) else: requiredLayout(bool)
    of ptByte:
      if optional: optionalLayout(int8) else: requiredLayout(int8)
    of ptShort:
      if optional: optionalLayout(int16) else: requiredLayout(int16)
    of ptInt:
      if optional: optionalLayout(int64) else: requiredLayout(int64)
    of ptFloat:
      if optional: optionalLayout(float64) else: requiredLayout(float64)
    of ptChar:
      if optional: optionalLayout(uint16) else: requiredLayout(uint16)

  of etkString:
    if optional: optionalLayout(string) else: requiredLayout(string)

  of etkClass:
    if isConcreteStorageTypeName(typ.className):
      if optional:
        optionalLayout(EidoStorage[int8])
      else:
        requiredLayout(EidoStorage[int8])
    else:
      # All ordinary Nim-backend classes lower to ref object values.
      if optional: optionalLayout(pointer) else: requiredLayout(pointer)

  of etkInterface:
    # Interface values also lower to ref object handles in the current backend.
    if optional: optionalLayout(pointer) else: requiredLayout(pointer)
