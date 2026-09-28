## Builds protocol-neutral semantic symbol facts from checked HIR and compiler tokens.
## LSP/editor adapters consume these facts for highlighting, navigation, and later rename/reference features.

import std/[algorithm, os, sets, strutils, tables]
import ../frontend/lexer/[scanner, token]
import ../hir/[declarations, expressions, program, statements]
import ../project/model
import ../semantic/symbols/ids
import ../source/[source_unit, span]
import ../types/[function_result, method_kind, model]

type
  ToolingSymbolKind* = enum
    tskClass,
    tskInterface,
    tskFunction,
    tskMethod,
    tskProperty,
    tskParameter,
    tskVariable

  ToolingSymbol* = object
    kind*: ToolingSymbolKind
    name*: string
    span*: SourceSpan
    declarationSpan*: SourceSpan
    isDeclaration*: bool
    isStatic*: bool

  SymbolIndex* = object
    symbols*: seq[ToolingSymbol]

  SymbolMatch* = object
    found*: bool
    symbol*: ToolingSymbol

  TokenMatch = object
    found: bool
    token: Token

  TokenRegistry = Table[int, seq[Token]]
  TypeDefinitionRegistry = Table[string, SourceSpan]
  FieldDefinitionRegistry = Table[string, SourceSpan]
  MethodDefinitionRegistry = Table[int, SourceSpan]
  FunctionDefinitionRegistry = Table[int, SourceSpan]
  InterfaceMethodDefinitionRegistry = Table[string, SourceSpan]
  InterfaceRegistry = Table[string, HirInterface]

include symbols/source_tokens
include symbols/definitions
include symbols/expressions
include symbols/statements
include symbols/build_index
include symbols/queries
