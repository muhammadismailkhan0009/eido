## Defines compiler-owned naming helpers for Eido's generic Storage<T> capability.
## Storage is an SDK/runtime type constructor rather than an ordinary user declaration.

import std/strutils

const StorageTypeConstructorName* = "Storage"

## Returns the source-local portion of a canonical nominal name.
proc storageLocalName(name: string): string =
  let separator = name.rfind('.')
  if separator < 0: name else: name[separator + 1 .. ^1]

## Reports whether a name denotes the reserved Storage generic type constructor.
proc isStorageTypeConstructor*(name: string): bool =
  storageLocalName(name) == StorageTypeConstructorName

## Reports whether a specialized nominal name denotes Storage<T>.
proc isConcreteStorageTypeName*(name: string): bool =
  let localName = storageLocalName(name)
  localName.startsWith(StorageTypeConstructorName & "<") and
    localName.endsWith(">")

## Returns the concrete element spelling carried by Storage<T>.
## Current Storage specialization accepts only flat built-in element names.
proc storageElementName*(name: string): string =
  if not isConcreteStorageTypeName(name):
    return ""
  let localName = storageLocalName(name)
  localName[StorageTypeConstructorName.len + 1 ..< localName.len - 1]
