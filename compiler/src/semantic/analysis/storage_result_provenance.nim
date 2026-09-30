## Infers whether a Storage-valued callable result transfers ownership or returns a borrow.
## The initial model requires one consistent provenance across every return path.

import std/tables
import ../../diagnostics/errors
import ../../source/span
import ../../frontend/ast/[declarations, expressions, statements]
import ../../types/storage
import ../symbols/model

type
  StorageResultInference = enum
    sriNone,
    sriBorrowed,
    sriOwned,
    sriUnknown

## Classifies one expression whose surrounding callable is known to return Storage.
proc inferStorageExpr(
  expr: Expr,
  locals: Table[string, StorageResultInference]
): StorageResultInference =
  if expr.isNil:
    return sriNone
  case expr.kind
  of ekIdentifier:
    locals.getOrDefault(expr.name, sriUnknown)

  of ekFieldAccess:
    # Returning Storage reachable through an owning object/class field is a borrow.
    sriBorrowed

  of ekMethodCall:
    if expr.receiver.kind == ekIdentifier and
        isConcreteStorageTypeName(expr.receiver.name):
      case expr.methodName
      of "allocate", "allocateRaw", "fromAddress":
        sriOwned
      of "view", "slice":
        sriBorrowed
      else:
        sriUnknown
    else:
      sriUnknown

  of ekCall:
    sriUnknown

  else:
    sriUnknown

## Merges one return-path provenance into the callable-wide result.
proc mergeStorageResult(
  current: var StorageResultInference,
  candidate: StorageResultInference,
  span: SourceSpan
) =
  if candidate in {sriNone, sriUnknown}:
    failAt(
      span,
      "Storage result ownership cannot be inferred; return a Storage value with known owned or borrowed provenance"
    )

  if current == sriNone:
    current = candidate
    return

  if current != candidate:
    failAt(
      span,
      "Storage result ownership must be consistent across all return paths"
    )
## Scans one statement tree while tracking simple Storage local provenance.
proc scanStorageResults(
  statement: Stmt,
  locals: var Table[string, StorageResultInference],
  inferred: var StorageResultInference
) =
  case statement.kind
  of skVar:
    locals[statement.name] = inferStorageExpr(statement.initializer, locals)

  of skAssign:
    if statement.target.kind == ekIdentifier:
      locals[statement.target.name] =
        inferStorageExpr(statement.assignedValue, locals)

  of skReturn:
    if not statement.value.isNil:
      mergeStorageResult(
        inferred,
        inferStorageExpr(statement.value, locals),
        statement.value.span
      )

  of skIf:
    var thenLocals = locals
    for child in statement.thenBranch:
      scanStorageResults(child, thenLocals, inferred)
    var elseLocals = locals
    for child in statement.elseBranch:
      scanStorageResults(child, elseLocals, inferred)

  of skExists:
    var bodyLocals = locals
    for child in statement.existsBody:
      scanStorageResults(child, bodyLocals, inferred)

  of skWhile:
    var bodyLocals = locals
    for child in statement.body:
      scanStorageResults(child, bodyLocals, inferred)

  of skFor:
    var loopLocals = locals
    scanStorageResults(statement.forInitializer, loopLocals, inferred)
    for child in statement.forBody:
      scanStorageResults(child, loopLocals, inferred)
    scanStorageResults(statement.forUpdate, loopLocals, inferred)

  of skCall, skBreak, skContinue:
    discard
## Infers the Storage result provenance of one ordinary Eido callable.
proc inferStorageResultProvenance*(source: FunctionDecl): StorageValueProvenance =
  if source.result.kind != frrSingle or
      not isConcreteStorageTypeName(source.result.typeRef.name):
    return svpNotStorage

  if source.isNative:
    return svpOwned

  var locals = initTable[string, StorageResultInference]()
  for parameter in source.parameters:
    if isConcreteStorageTypeName(parameter.typeRef.name):
      locals[parameter.name] = sriBorrowed

  var inferred = sriNone
  for statement in source.body:
    scanStorageResults(statement, locals, inferred)

  case inferred
  of sriBorrowed:
    svpBorrowed
  of sriOwned:
    svpOwned
  of sriNone, sriUnknown:
    failAt(
      source.span,
      "Storage-valued callable must return Storage with inferable ownership provenance"
    )
