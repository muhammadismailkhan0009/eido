## Defines generic compiler memory metadata after private phase handles
## have been resolved back to stable semantic identities.

type
  CompileTimeFieldMetadata* = object
    fieldName*: string
    offset*: int64
    containsIdentity*: bool

  CompileTimeTypeMetadata* = object
    className*: string
    size*: int64
    alignment*: int64
    fields*: seq[CompileTimeFieldMetadata]

  CompileTimeCallableKind* = enum
    ctkFunction,
    ctkMethod

  CompileTimeIdentityValue* = object
    localId*: int
    sourceName*: string

  CompileTimeCallableMetadata* = object
    kind*: CompileTimeCallableKind
    semanticId*: int
    ownerName*: string
    sourceName*: string
    identityValues*: seq[CompileTimeIdentityValue]

  CompileTimeMemoryMetadata* = object
    types*: seq[CompileTimeTypeMetadata]
    callables*: seq[CompileTimeCallableMetadata]


## Reports whether one canonical class has compiler-described object layout metadata.
proc hasObjectLayout*(
  metadata: CompileTimeMemoryMetadata,
  className: string
): bool =
  for typeMetadata in metadata.types:
    if typeMetadata.className == className:
      return true
  false
