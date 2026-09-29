## Defines resolved symbol records used during semantic analysis.

import ../../source/span
import ../../types/model
import ../../types/function_result
import ../../types/method_kind
import ids

type
  ClassValueProvenance* = enum
    cvpNotClass,
    cvpExisting,
    cvpDetached

  BindingKind* = enum
    bkReceiver,
    bkParameter,
    bkVariable,
    bkField

  LocalSymbol* = object
    name*: string
    typ*: EidoType
    span*: SourceSpan
    classValueProvenance*: ClassValueProvenance
    case kind*: BindingKind
    of bkReceiver, bkParameter, bkVariable:
      id*: LocalId
    of bkField:
      receiverId*: LocalId
      ownerType*: EidoType

  FunctionSymbol* = object
    id*: FunctionId
    name*: string
    isNative*: bool
    parameterTypes*: seq[EidoType]
    result*: FunctionResult
    span*: SourceSpan

  MethodSymbol* = object
    id*: MethodId
    name*: string
    isNative*: bool
    kind*: MethodKind
    parameterTypes*: seq[EidoType]
    result*: FunctionResult
    span*: SourceSpan

  ClassFieldSymbol* = object
    name*: string
    typ*: EidoType
    span*: SourceSpan

  ClassSymbol* = object
    name*: string
    moduleName*: string
    typ*: EidoType
    implements*: seq[string]
    hasInvariant*: bool
    fields*: seq[ClassFieldSymbol]
    methods*: seq[MethodSymbol]
    span*: SourceSpan
