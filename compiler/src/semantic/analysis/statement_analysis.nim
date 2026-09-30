## Checks statement rules and lowers statements to resolved HIR. Example: `notify(10);` becomes a resolved call statement, while `return;` is checked against a no-result function.

import ../../diagnostics/errors
import ../../frontend/ast/statements as astStatements
import ../../frontend/ast/expressions as astExpressions
import ../../hir/statements as hirStatements
import ../../hir/expressions
import ../../types/model
import ../../types/function_result
import ../../types/storage
import ../symbols/model
import ../symbols/functions
import ../symbols/nominals
import ../symbols/scope
import expression_analysis
import storage_value_provenance
import optional_paths

## Checks one AST statement and lowers it to HIR.
## Example: conditional branches recursively reuse the same statement-analysis entry point.
proc analyzeStmt*(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols,
  functionResult: FunctionResult,
  loopDepth: int = 0
): hirStatements.HirStmt

include statement/scoped_blocks
include statement/conditional_statements
include statement/while_statements
include statement/for_statements
include statement/loop_control_statements
include statement/class_relationship_mutation

## Returns the root owner local borrowed by a Storage view/slice initializer.
proc storageBorrowOwner(
  source: astExpressions.Expr,
  analyzed: HirExpr,
  locals: LocalScope
): string =
  if analyzed.typ.kind != etkClass or
      not isConcreteStorageTypeName(analyzed.typ.className) or
      source.kind != astExpressions.ekMethodCall or
      source.methodName notin ["view", "slice"] or
      source.methodArguments.len == 0:
    return ""

  let origin = source.methodArguments[0]
  if origin.kind != astExpressions.ekIdentifier or
      not locals.contains(origin.name):
    return ""

  let originSymbol = locals.get(origin.name)
  if originSymbol.storageValueProvenance == svpBorrowed and
      originSymbol.storageBorrowOwner.len > 0:
    return originSymbol.storageBorrowOwner
  origin.name


## Checks one AST statement and lowers it to HIR. Example: `set b = a;` verifies `b` exists, checks types, and stores resolved mutation HIR.
proc analyzeStmt*(
  stmt: astStatements.Stmt,
  locals: var LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols,
  functionResult: FunctionResult,
  loopDepth: int = 0
): hirStatements.HirStmt =
  case stmt.kind
  of astStatements.skVar:
    if locals.contains(stmt.name):
      let existing = locals.get(stmt.name)
      case existing.kind
      of bkReceiver:
        failAt(stmt.span, "local name 'self' is reserved for the current receiver")
      of bkField:
        failAt(
          stmt.span,
          "local '" & stmt.name & "' conflicts with class field"
        )
      of bkParameter:
        failAt(
          stmt.span,
          "local '" & stmt.name & "' conflicts with parameter"
        )
      of bkVariable:
        failAt(stmt.span, "duplicate local '" & stmt.name & "'")

    let initializer =
      if stmt.initializer.kind == astExpressions.ekClassRelation:
        analyzeClassValueRelation(
          stmt.initializer,
          locals,
          functions,
          classes
        )
      else:
        analyzeExpr(stmt.initializer, locals, functions, classes)

    if initializer.typ.kind == etkClass and
        stmt.initializer.kind notin {
          astExpressions.ekConstruct,
          astExpressions.ekCall,
          astExpressions.ekMethodCall,
          astExpressions.ekClassRelation
        }:
      failAt(
        stmt.initializer.span,
        "existing class local binding requires explicit copy or ref"
      )

    if initializer.typ.kind != etkClass and
        stmt.initializer.kind == astExpressions.ekIdentifier:
      failAt(
        stmt.initializer.span,
        "bare identifier initializer remains unsupported"
      )

    let localId = locals.nextLocalId()
    let symbol = LocalSymbol(
      id: localId,
      name: stmt.name,
      typ: initializer.typ,
      kind: bkVariable,
      span: stmt.span,
      classValueProvenance:
        classValueProvenance(stmt.initializer, initializer, locals),
      storageValueProvenance:
        classifyStorageValue(
          stmt.initializer, initializer, locals, functions, classes
        ),
      storageBorrowOwner:
        storageBorrowOwner(stmt.initializer, initializer, locals),
      storageReleased: false
    )
    locals.add(stmt.name, symbol)

    HirStmt(
      kind: hskVar,
      span: stmt.span,
      localId: localId,
      sourceName: stmt.name,
      typ: initializer.typ,
      initializer: initializer
    )

  of astStatements.skAssign:
    case stmt.target.kind
    of astExpressions.ekIdentifier:
      let targetName = stmt.target.name
      if not locals.contains(targetName):
        failAt(stmt.span, "unknown set target '" & targetName & "'")

      let target = locals.get(targetName)
      case target.kind
      of bkReceiver:
        failAt(stmt.span, "'self' cannot be replaced with set")
      of bkParameter:
        failAt(stmt.span, "parameters cannot be mutated with set")
      of bkField:
        failAt(
          stmt.span,
          "own field '" & target.name & "' must be mutated through self." &
            target.name
        )
      of bkVariable:
        if target.typ.kind == etkClass and
            isConcreteStorageTypeName(target.typ.className) and
            target.storageValueProvenance == svpOwned and
            not target.storageReleased:
          failAt(
            stmt.span,
            "owning Storage must be released before its local binding can be replaced"
          )

        let value =
          if target.typ.kind == etkClass:
            analyzeClassRelationshipMutationValue(
              stmt.assignedValue,
              target.typ,
              locals,
              functions,
              classes
            )
          else:
            analyzeExprExpected(
              stmt.assignedValue,
              target.typ,
              locals,
              functions,
              classes
            )

        if target.typ.kind == etkClass:
          var updatedTarget = target
          updatedTarget.classValueProvenance = classValueProvenance(
            stmt.assignedValue,
            value,
            locals
          )
          updatedTarget.storageValueProvenance = classifyStorageValue(
            stmt.assignedValue,
            value,
            locals,
            functions,
            classes
          )
          updatedTarget.storageBorrowOwner = storageBorrowOwner(
            stmt.assignedValue,
            value,
            locals
          )
          updatedTarget.storageReleased = false
          locals.add(target.name, updatedTarget)

        HirStmt(
          kind: hskAssign,
          span: stmt.span,
          targetId: target.id,
          targetName: target.name,
          assignedValue: value
        )

    of astExpressions.ekFieldAccess:
      if stmt.target.target.kind != astExpressions.ekIdentifier or
          stmt.target.target.name != "self":
        failAt(stmt.target.span, "field mutation requires a self.<field> target")

      let target = analyzeExpr(stmt.target, locals, functions, classes)
      if target.kind != hekFieldAccess or target.target.kind != hekLocal:
        raise newException(
          ValueError,
          "semantic invariant: self field set did not resolve to field access"
        )

      let value =
        if target.typ.kind == etkClass:
          analyzeClassRelationshipMutationValue(
            stmt.assignedValue,
            target.typ,
            locals,
            functions,
            classes
          )
        else:
          analyzeExprExpected(
            stmt.assignedValue,
            target.typ,
            locals,
            functions,
            classes
          )

      HirStmt(
        kind: hskFieldSet,
        span: stmt.span,
        receiverId: target.target.localId,
        fieldName: target.sourceFieldName,
        fieldValue: value
      )

    else:
      failAt(
        stmt.target.span,
        "set target must be a mutable local or own field through self"
      )

  of astStatements.skCall:
    case stmt.call.kind
    of astExpressions.ekCall:
      HirStmt(
        kind: hskCall,
        span: stmt.span,
        call: analyzeCall(stmt.call, locals, functions, classes)
      )
    of astExpressions.ekMethodCall:
      let methodCall = analyzeMethodCall(
        stmt.call,
        locals,
        functions,
        classes
      )
      if stmt.call.receiver.kind == astExpressions.ekIdentifier and
          isConcreteStorageTypeName(stmt.call.receiver.name) and
          stmt.call.methodName == "release" and
          stmt.call.methodArguments.len == 1 and
          stmt.call.methodArguments[0].kind == astExpressions.ekIdentifier:
        locals.markStorageReleased(stmt.call.methodArguments[0].name)
      HirStmt(
        kind: hskMethodCall,
        span: stmt.span,
        methodCall: methodCall
      )
    else:
      raise newException(
        ValueError,
        "semantic invariant: call statement has non-call expression"
      )

  of astStatements.skReturn:
    case functionResult.kind
    of frNone:
      if not stmt.value.isNil:
        failAt(stmt.span, "function does not return a value; use 'return;'")
      HirStmt(
        kind: hskReturn,
        span: stmt.span,
        value: nil
      )

    of frSingle:
      if stmt.value.isNil:
        failAt(
          stmt.span,
          "function must return " & functionResult.typ.displayName
        )

      if stmt.value.kind == astExpressions.ekClassRelation:
        failAt(
          stmt.value.span,
          "copy/ref cannot be used directly in return statements"
        )

      let returnValue = analyzeExprExpected(
        stmt.value,
        functionResult.typ,
        locals,
        functions,
        classes
      )

      if functionResult.typ.kind == etkClass and
          not isConcreteStorageTypeName(functionResult.typ.className) and
          stmt.value.kind != astExpressions.ekNone and
          classValueProvenance(stmt.value, returnValue, locals) != cvpDetached:
        failAt(
          stmt.value.span,
          "class return must produce a fresh/detached object"
        )

      HirStmt(
        kind: hskReturn,
        span: stmt.span,
        value: returnValue
      )

  of astStatements.skIf:
    analyzeConditional(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skExists:
    analyzeExists(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skWhile:
    analyzeWhile(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skFor:
    analyzeFor(
      stmt,
      locals,
      functions,
      classes,
      functionResult,
      loopDepth
    )

  of astStatements.skBreak, astStatements.skContinue:
    analyzeLoopControl(stmt, loopDepth)
