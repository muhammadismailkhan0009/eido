## Adds callable parameter declarations and their nominal type references.
proc addParameters(
  parameters: seq[HirParameter],
  index: var SymbolIndex,
  seen: var HashSet[string],
  registry: TokenRegistry,
  typeDefinitions: TypeDefinitionRegistry,
  localDefinitions: var Table[int, ToolingSymbol]
) =
  for parameter in parameters:
    let nameToken = registry.findNameToken(
      parameter.span,
      parameter.sourceName,
      chooseLast = true
    )
    if nameToken.found:
      let definition = ToolingSymbol(
        kind: tskParameter,
        name: parameter.sourceName,
        span: nameToken.token.span,
        declarationSpan: nameToken.token.span,
        isDeclaration: true
      )
      localDefinitions[parameter.localId.value] = definition
      index.addSymbol(
        seen,
        tskParameter,
        parameter.sourceName,
        definition.span,
        definition.declarationSpan,
        true
      )

    index.addTypeUse(
      seen,
      registry,
      typeDefinitions,
      parameter.span,
      parameter.typ
    )

## Builds a reusable semantic symbol index for one checked project.
proc buildSymbolIndex*(
  program: HirProgram,
  project: EidoProject
): SymbolIndex =
  let registry = buildTokenRegistry(project)
  var seen = initHashSet[string]()
  var typeDefinitions = initTable[string, SourceSpan]()
  var fieldDefinitions = initTable[string, SourceSpan]()
  var methodDefinitions = initTable[int, SourceSpan]()
  var functionDefinitions = initTable[int, SourceSpan]()
  var interfaceMethodDefinitions =
    initTable[string, SourceSpan]()
  var interfaces = initTable[string, HirInterface]()

  # Pass 1: declaration identities and exact declaration-name spans.
  for interfaceDecl in program.interfaces:
    let canonicalName = interfaceDecl.typ.interfaceName
    let nameToken = registry.findDeclarationNameToken(
      interfaceDecl.span,
      tkInterface,
      interfaceDecl.sourceName
    )
    if nameToken.found:
      typeDefinitions[canonicalName] = nameToken.token.span
      result.addSymbol(
        seen,
        tskInterface,
        sourceBaseName(canonicalName),
        nameToken.token.span,
        nameToken.token.span,
        true
      )

    interfaces[canonicalName] = interfaceDecl

    for methodDecl in interfaceDecl.methods:
      let methodToken = registry.findDeclarationNameToken(
        interfaceDecl.span,
        tkFunction,
        methodDecl.sourceName
      )
      if methodToken.found:
        let key = interfaceMethodKey(
          canonicalName,
          methodDecl.sourceName
        )
        interfaceMethodDefinitions[key] = methodToken.token.span
        result.addSymbol(
          seen,
          tskMethod,
          methodDecl.sourceName,
          methodToken.token.span,
          methodToken.token.span,
          true
        )

  for classDecl in program.classes:
    let canonicalName = classDecl.typ.className
    let nameToken = registry.findDeclarationNameToken(
      classDecl.span,
      tkClass,
      classDecl.sourceName
    )
    if nameToken.found:
      typeDefinitions[canonicalName] = nameToken.token.span
      result.addSymbol(
        seen,
        tskClass,
        sourceBaseName(canonicalName),
        nameToken.token.span,
        nameToken.token.span,
        true
      )

    for field in classDecl.fields:
      let fieldToken = registry.findNameToken(
        field.span,
        field.sourceName,
        chooseLast = true
      )
      if fieldToken.found:
        fieldDefinitions[fieldKey(canonicalName, field.sourceName)] =
          fieldToken.token.span
        result.addSymbol(
          seen,
          tskProperty,
          field.sourceName,
          fieldToken.token.span,
          fieldToken.token.span,
          true
        )

    for methodDecl in classDecl.methods:
      let methodToken = registry.findDeclarationNameToken(
        methodDecl.span,
        tkFunction,
        methodDecl.sourceName
      )
      if methodToken.found:
        methodDefinitions[methodDecl.methodId.value] = methodToken.token.span
        result.addSymbol(
          seen,
          tskMethod,
          methodDecl.sourceName,
          methodToken.token.span,
          methodToken.token.span,
          true,
          methodDecl.kind == mkStatic
        )

  for functionDecl in program.functions:
    let functionToken = registry.findDeclarationNameToken(
      functionDecl.span,
      tkFunction,
      functionDecl.sourceName
    )
    if functionToken.found:
      functionDefinitions[functionDecl.functionId.value] =
        functionToken.token.span
      result.addSymbol(
        seen,
        tskFunction,
        sourceBaseName(functionDecl.sourceName),
        functionToken.token.span,
        functionToken.token.span,
        true
      )

  # Pass 2: declaration signatures and callable bodies.
  for interfaceDecl in program.interfaces:
    for parent in interfaceDecl.extends:
      let parentType = interfaceType(parent)
      result.addTypeUse(
        seen,
        registry,
        typeDefinitions,
        interfaceDecl.span,
        parentType
      )

    for methodDecl in interfaceDecl.methods:
      var localDefinitions = initTable[int, ToolingSymbol]()
      methodDecl.parameters.addParameters(
        result,
        seen,
        registry,
        typeDefinitions,
        localDefinitions
      )
      for clause in methodDecl.requires:
        visitExpr(
          clause, result, seen, registry, typeDefinitions, fieldDefinitions,
          methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
          interfaces, localDefinitions
        )
      for clause in methodDecl.ensures:
        visitExpr(
          clause, result, seen, registry, typeDefinitions, fieldDefinitions,
          methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
          interfaces, localDefinitions
        )

  for classDecl in program.classes:
    for implemented in classDecl.implements:
      result.addTypeUse(
        seen,
        registry,
        typeDefinitions,
        classDecl.span,
        interfaceType(implemented)
      )

    for field in classDecl.fields:
      result.addTypeUse(
        seen,
        registry,
        typeDefinitions,
        field.span,
        field.typ
      )

    var invariantLocalDefinitions = initTable[int, ToolingSymbol]()
    for clause in classDecl.invariants:
      visitExpr(
        clause,
        result,
        seen,
        registry,
        typeDefinitions,
        fieldDefinitions,
        methodDefinitions,
        functionDefinitions,
        interfaceMethodDefinitions,
        interfaces,
        invariantLocalDefinitions
      )

    for methodDecl in classDecl.methods:
      var localDefinitions = initTable[int, ToolingSymbol]()
      methodDecl.parameters.addParameters(
        result,
        seen,
        registry,
        typeDefinitions,
        localDefinitions
      )

      if methodDecl.result.kind == frSingle:
        let resultToken = registry.findResultTypeToken(
          methodDecl.span,
          methodDecl.result.typ
        )
        let resultTypeName = methodDecl.result.typ.nominalTypeName
        if resultToken.found and resultTypeName in typeDefinitions:
          result.addSymbol(
            seen,
            if methodDecl.result.typ.kind == etkClass:
              tskClass
            else:
              tskInterface,
            sourceBaseName(resultTypeName),
            resultToken.token.span,
            typeDefinitions[resultTypeName],
            false
          )

      for clause in methodDecl.requires:
        visitExpr(
          clause, result, seen, registry, typeDefinitions, fieldDefinitions,
          methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
          interfaces, localDefinitions
        )
      for clause in methodDecl.ensures:
        visitExpr(
          clause, result, seen, registry, typeDefinitions, fieldDefinitions,
          methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
          interfaces, localDefinitions
        )

      for stmt in methodDecl.body:
        visitStmt(
          stmt,
          classDecl.typ,
          result,
          seen,
          registry,
          typeDefinitions,
          fieldDefinitions,
          methodDefinitions,
          functionDefinitions,
          interfaceMethodDefinitions,
          interfaces,
          localDefinitions
        )

  for functionDecl in program.functions:
    var localDefinitions = initTable[int, ToolingSymbol]()
    functionDecl.parameters.addParameters(
      result,
      seen,
      registry,
      typeDefinitions,
      localDefinitions
    )

    if functionDecl.result.kind == frSingle:
      let resultToken = registry.findResultTypeToken(
        functionDecl.span,
        functionDecl.result.typ
      )
      let resultTypeName = functionDecl.result.typ.nominalTypeName
      if resultToken.found and resultTypeName in typeDefinitions:
        result.addSymbol(
          seen,
          if functionDecl.result.typ.kind == etkClass:
            tskClass
          else:
            tskInterface,
          sourceBaseName(resultTypeName),
          resultToken.token.span,
          typeDefinitions[resultTypeName],
          false
        )

    for clause in functionDecl.requires:
      visitExpr(
        clause, result, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )
    for clause in functionDecl.ensures:
      visitExpr(
        clause, result, seen, registry, typeDefinitions, fieldDefinitions,
        methodDefinitions, functionDefinitions, interfaceMethodDefinitions,
        interfaces, localDefinitions
      )

    for stmt in functionDecl.body:
      visitStmt(
        stmt,
        EidoType(kind: etkString),
        result,
        seen,
        registry,
        typeDefinitions,
        fieldDefinitions,
        methodDefinitions,
        functionDefinitions,
        interfaceMethodDefinitions,
        interfaces,
        localDefinitions
      )

  result.symbols.sort(proc(left, right: ToolingSymbol): int =
    if left.span.sourceId.value != right.span.sourceId.value:
      cmp(left.span.sourceId.value, right.span.sourceId.value)
    elif left.span.startOffset != right.span.startOffset:
      cmp(left.span.startOffset, right.span.startOffset)
    else:
      cmp(left.span.endOffset, right.span.endOffset)
  )
