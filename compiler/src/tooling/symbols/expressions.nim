## Walks one expression and adds resolved symbol references.
proc visitExpr(
  expr: HirExpr,
  index: var SymbolIndex,
  seen: var HashSet[string],
  registry: TokenRegistry,
  typeDefinitions: TypeDefinitionRegistry,
  fieldDefinitions: FieldDefinitionRegistry,
  methodDefinitions: MethodDefinitionRegistry,
  functionDefinitions: FunctionDefinitionRegistry,
  interfaceMethodDefinitions: InterfaceMethodDefinitionRegistry,
  interfaces: InterfaceRegistry,
  localDefinitions: Table[int, ToolingSymbol]
) =
  if expr.isNil:
    return

  case expr.kind
  of hekLocal:
    index.addLocalReference(seen, localDefinitions, expr)

  of hekCall:
    let callName = sourceBaseName(expr.call.functionName)
    let nameToken = registry.findNameToken(expr.call.span, callName)
    if nameToken.found and expr.call.functionId.value in functionDefinitions:
      index.addSymbol(
        seen,
        tskFunction,
        callName,
        nameToken.token.span,
        functionDefinitions[expr.call.functionId.value],
        false
      )
    for argument in expr.call.arguments:
      visitExpr(
        argument, index, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )

  of hekConstruct:
    let nominalName = expr.typ.nominalTypeName
    if nominalName in typeDefinitions:
      let typeToken = registry.findNameToken(expr.span, nominalName)
      if typeToken.found:
        index.addSymbol(
          seen,
          tskClass,
          sourceBaseName(nominalName),
          typeToken.token.span,
          typeDefinitions[nominalName],
          false
        )

    for field in expr.fields:
      let key = fieldKey(nominalName, field.sourceName)
      let fieldToken = registry.findNameToken(
        field.span,
        field.sourceName
      )
      if fieldToken.found and key in fieldDefinitions:
        index.addSymbol(
          seen,
          tskProperty,
          field.sourceName,
          fieldToken.token.span,
          fieldDefinitions[key],
          false
        )
      visitExpr(
        field.value, index, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )

  of hekFieldAccess:
    visitExpr(
      expr.target, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )
    if expr.target.typ.kind == etkClass:
      let ownerName = expr.target.typ.className
      let key = fieldKey(ownerName, expr.sourceFieldName)
      let fieldToken = registry.findNameToken(
        expr.span,
        expr.sourceFieldName,
        expr.target.span.endOffset
      )
      if fieldToken.found and key in fieldDefinitions:
        index.addSymbol(
          seen,
          tskProperty,
          expr.sourceFieldName,
          fieldToken.token.span,
          fieldDefinitions[key],
          false
        )

  of hekMethodCall:
    if expr.methodCall.kind == mkInstance:
      visitExpr(
        expr.methodCall.receiver,
        index, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )

    let methodToken =
      if expr.methodCall.kind == mkInstance:
        registry.findNameToken(
          expr.methodCall.span,
          expr.methodCall.methodName,
          expr.methodCall.receiver.span.endOffset,
          requireDotBefore = true
        )
      else:
        registry.findNameToken(
          expr.methodCall.span,
          expr.methodCall.methodName,
          requireDotBefore = true
        )

    var methodDefinition: SourceSpan
    var hasMethodDefinition = false
    if expr.methodCall.dispatchKind == hmdClass and
        expr.methodCall.methodId.value in methodDefinitions:
      methodDefinition = methodDefinitions[expr.methodCall.methodId.value]
      hasMethodDefinition = true
    elif expr.methodCall.dispatchKind == hmdInterface:
      var visiting = initHashSet[string]()
      methodDefinition = resolveInterfaceMethodDefinition(
        interfaceMethodDefinitions,
        interfaces,
        expr.methodCall.ownerType.interfaceName,
        expr.methodCall.methodName,
        visiting
      )
      hasMethodDefinition =
        methodDefinition.endOffset > methodDefinition.startOffset or
        methodDefinition.sourcePath.len > 0

    if methodToken.found and hasMethodDefinition:
      index.addSymbol(
        seen,
        tskMethod,
        expr.methodCall.methodName,
        methodToken.token.span,
        methodDefinition,
        false,
        expr.methodCall.kind == mkStatic
      )

    if expr.methodCall.kind == mkStatic:
      index.addTypeUse(
        seen,
        registry,
        typeDefinitions,
        expr.methodCall.span,
        expr.methodCall.ownerType
      )

    for argument in expr.methodCall.arguments:
      visitExpr(
        argument, index, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )

  of hekClassRelation:
    visitExpr(
      expr.relatedValue, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hekInterfaceConvert:
    visitExpr(
      expr.interfaceValue, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hekOptionalSome, hekOptionalGet:
    visitExpr(
      expr.optionalValue, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hekUnary:
    visitExpr(
      expr.operand, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hekBinary:
    visitExpr(
      expr.left, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )
    visitExpr(
      expr.right, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hekInteger, hekFloating, hekBoolean, hekChar, hekString, hekNone:
    discard
