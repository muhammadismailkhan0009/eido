## Resolves explicit class identity relations used at persistent relationship boundaries.

## Validates one explicit copy/ref relation and lowers it to typed HIR.
proc analyzeClassValueRelation*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols,
  classes: NominalSymbols
): hirExpressions.HirExpr =
  if expr.kind != astExpressions.ekClassRelation:
    failAt(expr.span, "expected copy/ref class relation")

  if expr.relatedValue.kind in {
      astExpressions.ekCall,
      astExpressions.ekMethodCall,
      astExpressions.ekConstruct,
      astExpressions.ekClassRelation
  }:
    failAt(
      expr.span,
      "copy/ref require an existing class object, not a fresh/call result"
    )

  let value = analyzeExpr(expr.relatedValue, locals, functions, classes)
  if value.typ.kind != etkClass:
    failAt(expr.span, "copy/ref may only target class values")

  HirExpr(
    kind: hekClassRelation,
    span: expr.span,
    typ: value.typ,
    classRelationKind:
      if expr.relationKind == astExpressions.cvrCopy:
        hcvrCopy
      else:
        hcvrRef,
    relatedValue: value
  )

## Classifies whether a class expression denotes existing or detached identity.
proc classValueProvenance*(
  source: astExpressions.Expr,
  analyzed: hirExpressions.HirExpr,
  locals: LocalScope
): ClassValueProvenance =
  if analyzed.typ.kind != etkClass:
    return cvpNotClass

  case source.kind
  of astExpressions.ekClassRelation:
    if source.relationKind == astExpressions.cvrCopy:
      cvpDetached
    else:
      cvpExisting

  of astExpressions.ekConstruct,
      astExpressions.ekCall,
      astExpressions.ekMethodCall:
    cvpDetached
  of astExpressions.ekIdentifier:
    if not locals.contains(source.name):
      cvpExisting
    else:
      locals.get(source.name).classValueProvenance

  of astExpressions.ekFieldAccess:
    cvpExisting

  else:
    cvpExisting
