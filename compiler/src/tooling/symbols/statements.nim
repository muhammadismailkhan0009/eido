## Walks one statement and adds declarations plus resolved references.
proc visitStmt(
  stmt: HirStmt,
  ownerType: EidoType,
  index: var SymbolIndex,
  seen: var HashSet[string],
  registry: TokenRegistry,
  typeDefinitions: TypeDefinitionRegistry,
  fieldDefinitions: FieldDefinitionRegistry,
  methodDefinitions: MethodDefinitionRegistry,
  functionDefinitions: FunctionDefinitionRegistry,
  interfaceMethodDefinitions: InterfaceMethodDefinitionRegistry,
  interfaces: InterfaceRegistry,
  localDefinitions: var Table[int, ToolingSymbol]
) =
  if stmt.isNil:
    return

  case stmt.kind
  of hskVar:
    visitExpr(
      stmt.initializer, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

    let nameToken = registry.findNameToken(stmt.span, stmt.sourceName)
    if nameToken.found:
      let definition = ToolingSymbol(
        kind: tskVariable,
        name: stmt.sourceName,
        span: nameToken.token.span,
        declarationSpan: nameToken.token.span,
        isDeclaration: true
      )
      localDefinitions[stmt.localId.value] = definition
      index.addSymbol(
        seen,
        tskVariable,
        stmt.sourceName,
        definition.span,
        definition.declarationSpan,
        true
      )

  of hskAssign:
    let targetToken = registry.findNameToken(stmt.span, stmt.targetName)
    if targetToken.found and stmt.targetId.value in localDefinitions:
      let definition = localDefinitions[stmt.targetId.value]
      index.addSymbol(
        seen,
        definition.kind,
        stmt.targetName,
        targetToken.token.span,
        definition.declarationSpan,
        false
      )
    visitExpr(
      stmt.assignedValue, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hskFieldSet:
    if ownerType.kind == etkClass:
      let key = fieldKey(ownerType.className, stmt.fieldName)
      let fieldToken = registry.findNameToken(
        stmt.span,
        stmt.fieldName,
        requireDotBefore = true
      )
      if fieldToken.found and key in fieldDefinitions:
        index.addSymbol(
          seen,
          tskProperty,
          stmt.fieldName,
          fieldToken.token.span,
          fieldDefinitions[key],
          false
        )
    visitExpr(
      stmt.fieldValue, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hskCall:
    let callName = sourceBaseName(stmt.call.functionName)
    let nameToken = registry.findNameToken(stmt.call.span, callName)
    if nameToken.found and stmt.call.functionId.value in functionDefinitions:
      index.addSymbol(
        seen,
        tskFunction,
        callName,
        nameToken.token.span,
        functionDefinitions[stmt.call.functionId.value],
        false
      )
    for argument in stmt.call.arguments:
      visitExpr(
        argument, index, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )

  of hskMethodCall:
    let wrapper = HirExpr(
      kind: hekMethodCall,
      span: stmt.methodCall.span,
      typ:
        if stmt.methodCall.result.kind == frSingle:
          stmt.methodCall.result.typ
        else:
          ownerType,
      methodCall: stmt.methodCall
    )
    visitExpr(
      wrapper, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hskReturn:
    visitExpr(
      stmt.value, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )

  of hskIf:
    visitExpr(
      stmt.condition, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )
    for child in stmt.thenBranch:
      visitStmt(
        child, ownerType, index, seen, registry, typeDefinitions,
        fieldDefinitions, methodDefinitions, functionDefinitions,
        interfaceMethodDefinitions, interfaces, localDefinitions
      )
    for child in stmt.elseBranch:
      visitStmt(
        child, ownerType, index, seen, registry, typeDefinitions,
        fieldDefinitions, methodDefinitions, functionDefinitions,
        interfaceMethodDefinitions, interfaces, localDefinitions
      )

  of hskExists:
    visitExpr(
      stmt.existsValue, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )
    for child in stmt.existsBody:
      visitStmt(
        child, ownerType, index, seen, registry, typeDefinitions,
        fieldDefinitions, methodDefinitions, functionDefinitions,
        interfaceMethodDefinitions, interfaces, localDefinitions
      )

  of hskWhile:
    visitExpr(
      stmt.whileCondition, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )
    for child in stmt.body:
      visitStmt(
        child, ownerType, index, seen, registry, typeDefinitions,
        fieldDefinitions, methodDefinitions, functionDefinitions,
        interfaceMethodDefinitions, interfaces, localDefinitions
      )

  of hskFor:
    visitStmt(
      stmt.forInitializer, ownerType, index, seen, registry, typeDefinitions,
      fieldDefinitions, methodDefinitions, functionDefinitions,
      interfaceMethodDefinitions, interfaces, localDefinitions
    )
    visitExpr(
      stmt.forCondition, index, seen, registry, typeDefinitions, fieldDefinitions,
      methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
      interfaces, localDefinitions
    )
    visitStmt(
      stmt.forUpdate, ownerType, index, seen, registry, typeDefinitions,
      fieldDefinitions, methodDefinitions, functionDefinitions,
      interfaceMethodDefinitions, interfaces, localDefinitions
    )
    for child in stmt.forBody:
      visitStmt(
        child, ownerType, index, seen, registry, typeDefinitions,
        fieldDefinitions, methodDefinitions, functionDefinitions,
        interfaceMethodDefinitions, interfaces, localDefinitions
      )

  of hskBreak, hskContinue:
    discard
