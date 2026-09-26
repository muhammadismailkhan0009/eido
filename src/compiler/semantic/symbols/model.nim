## Defines resolved symbol records used during semantic analysis. Example: function `notify(Int id)` stores one Int parameter type and an `frNone` result contract.

import ../../source/span
import ../../types/model
import ../../types/function_result
import ids

type
  BindingKind* = enum
    bkParameter,
    bkVariable

  LocalSymbol* = object
    id*: LocalId
    name*: string
    typ*: EidoType
    kind*: BindingKind
    span*: SourceSpan

  FunctionSymbol* = object
    id*: FunctionId
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
    span*: SourceSpan
