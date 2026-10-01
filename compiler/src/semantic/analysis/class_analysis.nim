## Resolves class field schemas after all nominal class names have been registered.

import std/sets
import ../../diagnostics/errors
import ../../frontend/ast/declarations as astDeclarations
import ../../hir/declarations as hirDeclarations
import ../../types/model
import ../../types/storage
import ../symbols/[functions, ids, model, scope]
import ../symbols/nominals
import type_resolution
import expression_analysis
import contracts

## Resolves one class declaration and rejects duplicate field names.
proc analyzeClass*(
  source: astDeclarations.ClassDecl,
  classes: NominalSymbols
): hirDeclarations.HirClass =
  var fieldNames = initHashSet[string]()
  var fields: seq[hirDeclarations.HirField]
  var classFields: seq[hirDeclarations.HirClassField]

  for field in source.fields:
    if field.name in fieldNames:
      failAt(field.span, "duplicate field '" & field.name & "'")
    fieldNames.incl field.name

    let resolvedType = resolveDeclaredType(field.typeRef, classes)
    if field.isClassOwned:
      classFields.add hirDeclarations.HirClassField(
        span: field.span,
        sourceName: field.name,
        typ: resolvedType,
        initializer: nil
      )
    else:
      fields.add hirDeclarations.HirField(
        span: field.span,
        sourceName: field.name,
        typ: resolvedType
      )

  hirDeclarations.HirClass(
    span: source.span,
    sourceName: source.name,
    typ: classes.getClass(source.name).typ,
    implements: source.implements,
    fields: fields,
    classFields: classFields,
    invariants: @[],
    invariantReceiverLocalId: LocalId(-1),
    methods: @[]
  )

## Resolves class-owned field initializers after callable signatures are available.
proc analyzeClassFieldInitializers*(
  source: astDeclarations.ClassDecl,
  analyzed: var hirDeclarations.HirClass,
  functions: FunctionSymbols,
  classes: NominalSymbols
) =
  var locals = initLocalScope()
  var classFieldIndex = 0

  for field in source.fields:
    if not field.isClassOwned:
      continue

    let target = analyzed.classFields[classFieldIndex]
    if target.typ.kind == etkInterface or
        (target.typ.kind == etkClass and
          not isConcreteStorageTypeName(target.typ.className)):
      failAt(
        field.span,
        "class-owned managed fields are not yet supported"
      )

    analyzed.classFields[classFieldIndex].initializer = analyzeExprExpected(
      field.initializer,
      target.typ,
      locals,
      functions,
      classes
    )
    inc classFieldIndex

## Resolves class invariants after field and method symbols are available.
proc analyzeClassInvariants*(
  source: astDeclarations.ClassDecl,
  analyzed: var hirDeclarations.HirClass,
  owner: ClassSymbol,
  functions: FunctionSymbols,
  classes: NominalSymbols
) =
  if source.invariants.len == 0:
    return

  var locals = initLocalScope()
  let receiverLocalId = locals.nextLocalId()
  locals.add(
    "self",
    LocalSymbol(
      name: "self",
      typ: owner.typ,
      span: source.span,
      kind: bkReceiver,
      id: receiverLocalId,
      classValueProvenance: cvpExisting
    )
  )

  for field in owner.fields:
    locals.add(
      field.name,
      LocalSymbol(
        name: field.name,
        typ: field.typ,
        span: field.span,
        kind: bkField,
        receiverId: receiverLocalId,
        ownerType: owner.typ,
        classValueProvenance:
          if field.typ.kind == etkClass: cvpExisting else: cvpNotClass
      )
    )

  analyzed.invariantReceiverLocalId = receiverLocalId
  analyzed.invariants = analyzeContractClauses(
    source.invariants, locals, functions, classes, "invariant"
  )
