## Resolves class field schemas after all nominal class names have been registered.

import std/sets
import ../../diagnostics/errors
import ../../frontend/ast/declarations as astDeclarations
import ../../hir/declarations as hirDeclarations
import ../../types/model
import ../symbols/[functions, ids, model, scope]
import ../symbols/nominals
import type_resolution
import contracts

## Resolves one class declaration and rejects duplicate field names.
proc analyzeClass*(
  source: astDeclarations.ClassDecl,
  classes: NominalSymbols
): hirDeclarations.HirClass =
  var fieldNames = initHashSet[string]()
  var fields: seq[hirDeclarations.HirField]

  for field in source.fields:
    if field.name in fieldNames:
      failAt(field.span, "duplicate field '" & field.name & "'")
    fieldNames.incl field.name

    fields.add hirDeclarations.HirField(
      span: field.span,
      sourceName: field.name,
      typ: resolveDeclaredType(field.typeRef, classes)
    )

  hirDeclarations.HirClass(
    span: source.span,
    sourceName: source.name,
    typ: classes.getClass(source.name).typ,
    implements: source.implements,
    fields: fields,
    invariants: @[],
    invariantReceiverLocalId: LocalId(-1),
    methods: @[]
  )

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
