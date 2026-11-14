## Defines compiler naming helpers for Eido's Storage capability.
## Storage<Byte> is the compiler-provided raw substrate. Other Storage<T>
## specializations are ordinary SDK Eido wrappers over that raw capability.

import std/strutils

const
  StorageTypeConstructorName* = "Storage"
  StorageSdkModuleName* = "eido.stdlib.storage"
  StorageInternalFromRaw* = "compilerFromRaw"
  StorageInternalRaw* = "compilerRaw"
  StorageInternalRead* = "compilerRead"
  StorageInternalWrite* = "compilerWrite"

## Returns the source-local outer Storage name, ignoring module separators
## inside generic arguments (e.g. eido.stdlib.storage.Storage<app.Box>).
proc storageLocalName(name: string): string =
  let genericStart = name.find('<')
  let outerEnd = if genericStart < 0: name.len else: genericStart
  let separator = name[0 ..< outerEnd].rfind('.')
  if separator < 0: name else: name[separator + 1 .. ^1]

## Reports whether a name denotes the Storage generic type constructor.
proc isStorageTypeConstructor*(name: string): bool =
  storageLocalName(name) == StorageTypeConstructorName

## Reports whether one declaration is the SDK-owned public Storage<T> template.
proc isSdkStorageDeclaration*(moduleName, name: string): bool =
  moduleName == StorageSdkModuleName and isStorageTypeConstructor(name)

## Reports whether a specialized nominal name denotes Storage<T>.
proc isConcreteStorageTypeName*(name: string): bool =
  let localName = storageLocalName(name)
  localName.startsWith(StorageTypeConstructorName & "<") and
    localName.endsWith(">")

## Returns the concrete element spelling carried by Storage<T>.
proc storageElementName*(name: string): string =
  if not isConcreteStorageTypeName(name):
    return ""
  let localName = storageLocalName(name)
  localName[StorageTypeConstructorName.len + 1 ..< localName.len - 1]

## Reports whether one concrete Storage type is the compiler-provided raw byte substrate.
proc isRawStorageTypeName*(name: string): bool =
  isConcreteStorageTypeName(name) and storageElementName(name) == "Byte"

## Returns the sibling Storage<Byte> name for one concrete Storage<T> name.
proc rawStorageTypeName*(name: string): string =
  if not isConcreteStorageTypeName(name):
    return ""
  let localName = storageLocalName(name)
  let prefixLength = name.len - localName.len
  name[0 ..< prefixLength] & StorageTypeConstructorName & "<Byte>"

## Reports whether one method is a compiler-private typed/raw representation bridge.
proc isStorageInternalMethodName*(name: string): bool =
  name in [
    StorageInternalFromRaw,
    StorageInternalRaw,
    StorageInternalRead,
    StorageInternalWrite
  ]

## Reports whether one source path belongs to the SDK Storage implementation itself.
proc isStorageSdkSourcePath*(path: string): bool =
  path == "eido://stdlib/storage/storage.eido" or
    path.endsWith("/stdlib/storage/storage.eido")
