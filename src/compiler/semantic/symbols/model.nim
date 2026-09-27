## Defines resolved symbol records used during semantic analysis.

import ../../source/span
import ../../types/model
import ../../types/function_result
import ids

type
  BindingKind* = enum
    bkReceiver,
    bkParameter,
    bkVariable,
    bkField

  LocalSymbol* = object
    name*: string
    typ*: EidoType
    span*: SourceSpan
    case kind*: BindingKind
    of bkReceiver, bkParameter, bkVariable:
      id*: LocalId
    of bkField:
      receiverId*: LocalId
      ownerType*: EidoType

  FunctionSymbol* = object
    id*: FunctionId
    name*: string
    parameterTypes*: seq[EidoType]
    result*: FunctionResult
    span*: SourceSpan

  MethodSymbol* = object
    id*: MethodId
    name*: string
    parameterTypes*: seq[EidoType]
    result*: FunctionResult
    span*: SourceSpan

  ClassFieldSymbol* = object
    name*: string
    typ*: EidoType
    span*: SourceSpan

  ClassSymbol* = object
    name*: string
    typ*: EidoType
    fields*: seq[ClassFieldSymbol]
    methods*: seq[MethodSymbol]
    span*: SourceSpan
