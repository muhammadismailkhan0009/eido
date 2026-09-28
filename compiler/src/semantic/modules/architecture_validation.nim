## Enforces module architecture before ordinary Eido semantic analysis.
## Current classes are behavioral/identity classes, so only stateless static-only classes may cross module boundaries.
## Interface/data public API closure is intentionally deferred to those language features.

import std/[sets, strutils, tables]
import ../../diagnostics/errors
import ../../frontend/ast/[declarations, expressions, program, statements, type_references]
import ../../project/model as projectModel
import ../../project/modules/model as moduleModel
import ../../types/method_kind
import ../analysis/method_classification

type
  ClassRegistry = Table[string, ClassDecl]
  FunctionOwnerRegistry = Table[string, string]
  ModuleRegistry = Table[string, moduleModel.ModuleSpec]

## Documents the parentModuleName module helper behavior.
proc parentModuleName(name: string): string =
  let separator = name.rfind('.')
  if separator < 0: "" else: name[0 ..< separator]

## Documents the isDescendant module helper behavior.
proc isDescendant(parentName, candidate: string): bool =
  candidate.startsWith(parentName & ".")

## Documents the moduleReferenceCandidates module helper behavior.
proc moduleReferenceCandidates(
  modules: ModuleRegistry,
  rootModule, currentModule, reference: string
): seq[string] =
  var candidates: seq[string]

  template addIfPresent(candidate: string) =
    if candidate in modules and candidate notin candidates:
      candidates.add candidate

  addIfPresent(reference)
  addIfPresent(rootModule & "." & reference)

  var scope = currentModule
  while scope.len > 0:
    addIfPresent(scope & "." & reference)
    scope = parentModuleName(scope)

  candidates

## Documents the resolveModuleReference module helper behavior.
proc resolveModuleReference(
  modules: ModuleRegistry,
  rootModule, currentModule, reference, manifestPath: string
): string =
  let candidates = moduleReferenceCandidates(
    modules, rootModule, currentModule, reference
  )
  if candidates.len == 0:
    failAt(
      manifestPath, 1, 1,
      "unknown module reference '" & reference & "'"
    )
  if candidates.len > 1:
    failAt(
      manifestPath, 1, 1,
      "ambiguous module reference '" & reference & "': " &
        candidates.join(", ")
    )
  candidates[0]

## Documents the exportedSymbol module helper behavior.
proc exportedSymbol(
  modules: ModuleRegistry,
  rootModule: string,
  owner: moduleModel.ModuleSpec,
  reference: string
): tuple[moduleName, symbolName: string] =
  let separator = reference.rfind('.')
  if separator < 0:
    return (owner.canonicalName, reference)

  let moduleRef = reference[0 ..< separator]
  let symbolName = reference[separator + 1 .. ^1]
  let targetModule = resolveModuleReference(
    modules,
    rootModule,
    owner.canonicalName,
    moduleRef,
    owner.manifestPath
  )
  if not isDescendant(owner.canonicalName, targetModule):
    failAt(
      owner.manifestPath, 1, 1,
      "exported child symbol must come from a descendant module"
    )
  (targetModule, symbolName)

## Documents the isStaticOnly module helper behavior.
proc isStaticOnly(source: ClassDecl): bool =
  if source.fields.len != 0:
    return false
  for methodDecl in source.methods:
    if not methodDecl.isNative and inferMethodKind(methodDecl) != mkStatic:
      return false
  true

## Documents the moduleAncestors module helper behavior.
proc moduleAncestors(moduleName: string): seq[string] =
  var current = moduleName
  while current.len > 0:
    result.add current
    current = parentModuleName(current)

## Documents the resolveChildExport module helper behavior.
proc resolveChildExport(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  rootModule: string,
  parentModule: moduleModel.ModuleSpec,
  reference: string
): tuple[moduleName, symbolName: string] =
  let target = exportedSymbol(
    modules,
    rootModule,
    parentModule,
    reference
  )

  if target.moduleName == parentModule.canonicalName:
    return target

  let childSpec = modules[target.moduleName]
  var declared = false
  for childExport in childSpec.exports:
    let exported = exportedSymbol(
      modules,
      rootModule,
      childSpec,
      childExport
    )
    if exported.symbolName == target.symbolName:
      declared = true
      break

  if not declared:
    failAt(
      parentModule.manifestPath, 1, 1,
      "child module '" & target.moduleName & "' does not export '" &
        target.symbolName & "'"
    )

  target

## Documents the validateManifestSurfaces module helper behavior.
proc validateManifestSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  functions: FunctionOwnerRegistry,
  rootModule: string
) =
  for _, moduleSpec in modules:
    for exportRef in moduleSpec.exports:
      let target = resolveChildExport(
        modules,
        classes,
        rootModule,
        moduleSpec,
        exportRef
      )

      if target.symbolName in functions:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "top-level functions cannot be exported from modules"
        )

      if target.symbolName notin classes:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "unknown exported declaration '" & exportRef & "'"
        )

      let sourceClass = classes[target.symbolName]
      if sourceClass.moduleName != target.moduleName:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "export '" & exportRef & "' resolves to a declaration owned by '" &
            sourceClass.moduleName & "'"
        )

      if not isStaticOnly(sourceClass):
        failAt(
          sourceClass.span,
          "module export '" & exportRef &
            "' must be an interface, API data type, or static-only class; " &
            "concrete instance classes cannot cross module boundaries"
        )

    for adoption in moduleSpec.adopts:
      let target = resolveChildExport(
        modules,
        classes,
        rootModule,
        moduleSpec,
        adoption
      )
      if target.moduleName == moduleSpec.canonicalName:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "adopt must reference a child module export"
        )

## Documents the publicExportOwners module helper behavior.
proc publicExportOwners(
  modules: ModuleRegistry,
  rootModule, moduleName, symbolName: string
): seq[string] =
  if moduleName notin modules:
    return

  let moduleSpec = modules[moduleName]
  for exportRef in moduleSpec.exports:
    let target = exportedSymbol(
      modules,
      rootModule,
      moduleSpec,
      exportRef
    )
    if target.symbolName == symbolName and target.moduleName notin result:
      result.add target.moduleName

## Documents the familyAdoptedOwners module helper behavior.
proc familyAdoptedOwners(
  modules: ModuleRegistry,
  rootModule, currentModule, symbolName: string
): seq[string] =
  for ancestor in moduleAncestors(currentModule):
    if ancestor notin modules:
      continue
    let spec = modules[ancestor]

    # Public exports owned by ancestors propagate downward.
    for owner in publicExportOwners(
      modules, rootModule, ancestor, symbolName
    ):
      if owner notin result:
        result.add owner

    # Explicit adoption is family-visible but does not become public.
    for adoption in spec.adopts:
      let target = exportedSymbol(
        modules,
        rootModule,
        spec,
        adoption
      )
      if target.symbolName == symbolName and target.moduleName notin result:
        result.add target.moduleName

## Documents the effectiveDependencyNames module helper behavior.
proc effectiveDependencyNames(
  modules: ModuleRegistry,
  currentModule: string
): seq[string] =
  for ancestor in moduleAncestors(currentModule):
    if ancestor notin modules:
      continue
    for dependency in modules[ancestor].dependencies:
      if dependency notin result:
        result.add dependency

## Documents the visibleStaticOwners module helper behavior.
proc visibleStaticOwners(
  modules: ModuleRegistry,
  rootModule, currentModule, symbolName: string
): seq[string] =
  for owner in familyAdoptedOwners(
    modules, rootModule, currentModule, symbolName
  ):
    if owner notin result:
      result.add owner

  for dependency in effectiveDependencyNames(modules, currentModule):
    for owner in publicExportOwners(
      modules, rootModule, dependency, symbolName
    ):
      if owner notin result:
        result.add owner

## Documents the requireStaticVisibility module helper behavior.
proc requireStaticVisibility(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  rootModule, currentModule, className: string,
  spanPath: string,
  line, column: int
) =
  if className notin classes:
    return

  let target = classes[className]
  if target.moduleName == currentModule:
    return

  let owners = visibleStaticOwners(
    modules, rootModule, currentModule, className
  )
  if target.moduleName notin owners:
    failAt(
      spanPath, line, column,
      "module '" & currentModule & "' cannot access '" & className &
        "' from module '" & target.moduleName &
        "'; expose it through an allowed module boundary"
    )

## Documents the validateTypeRef module helper behavior.
proc validateTypeRef(
  source: TypeRef,
  currentModule: string,
  typeParameters: HashSet[string],
  classes: ClassRegistry
) =
  if source.name notin typeParameters and source.name in classes:
    let owner = classes[source.name].moduleName
    if owner != currentModule:
      failAt(
        source.span,
        "concrete class type '" & source.name & "' belongs to module '" &
          owner & "' and cannot cross into module '" & currentModule & "'"
      )

  for argument in source.arguments:
    validateTypeRef(argument, currentModule, typeParameters, classes)

## Documents the validateExpr module helper behavior.
proc validateExpr(
  source: Expr,
  currentModule: string,
  locals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  rootModule: string
)

## Documents the validateStmtBlock module helper behavior.
proc validateStmtBlock(
  statements: seq[Stmt],
  currentModule: string,
  initialLocals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  rootModule: string
)

## Documents the validateExpr module helper behavior.
proc validateExpr(
  source: Expr,
  currentModule: string,
  locals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  rootModule: string
) =
  if source.isNil:
    return

  case source.kind
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString, ekNone, ekIdentifier:
    discard

  of ekTypeReference:
    let typeRef = source.referencedTypeRef
    if typeRef.name in classes and typeRef.name notin typeParameters:
      requireStaticVisibility(
        modules, classes, rootModule, currentModule, typeRef.name,
        source.span.sourcePath, source.span.line, source.span.column
      )
    for argument in typeRef.arguments:
      validateTypeRef(argument, currentModule, typeParameters, classes)

  of ekCall:
    if source.callee in functions and functions[source.callee] != currentModule:
      failAt(
        source.span,
        "top-level function '" & source.callee &
          "' is internal to module '" & functions[source.callee] & "'"
      )
    for argument in source.arguments:
      validateExpr(
        argument, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

  of ekConstruct:
    validateTypeRef(
      source.constructionTypeRef,
      currentModule,
      typeParameters,
      classes
    )
    for field in source.fields:
      validateExpr(
        field.value, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

  of ekClassRelation:
    validateExpr(
      source.relatedValue, currentModule, locals, typeParameters,
      classes, functions, modules, rootModule
    )

  of ekFieldAccess:
    validateExpr(
      source.target, currentModule, locals, typeParameters,
      classes, functions, modules, rootModule
    )

  of ekMethodCall:
    if source.receiver.kind == ekIdentifier and
        source.receiver.name notin locals and
        source.receiver.name in classes:
      requireStaticVisibility(
        modules, classes, rootModule, currentModule, source.receiver.name,
        source.receiver.span.sourcePath,
        source.receiver.span.line,
        source.receiver.span.column
      )
    else:
      validateExpr(
        source.receiver, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    for argument in source.methodArguments:
      validateExpr(
        argument, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

  of ekUnary:
    validateExpr(
      source.operand, currentModule, locals, typeParameters,
      classes, functions, modules, rootModule
    )

  of ekBinary:
    validateExpr(
      source.left, currentModule, locals, typeParameters,
      classes, functions, modules, rootModule
    )
    validateExpr(
      source.right, currentModule, locals, typeParameters,
      classes, functions, modules, rootModule
    )

## Documents the validateStmtBlock module helper behavior.
proc validateStmtBlock(
  statements: seq[Stmt],
  currentModule: string,
  initialLocals: HashSet[string],
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  rootModule: string
) =
  var locals = initialLocals

  for statement in statements:
    case statement.kind
    of skVar:
      validateExpr(
        statement.initializer, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )
      locals.incl statement.name

    of skAssign:
      validateExpr(
        statement.target, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )
      validateExpr(
        statement.assignedValue, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skCall:
      validateExpr(
        statement.call, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skReturn:
      validateExpr(
        statement.value, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skIf:
      validateExpr(
        statement.condition, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.thenBranch, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.elseBranch, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skExists:
      validateExpr(
        statement.existsTarget, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.existsBody, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skWhile:
      validateExpr(
        statement.whileCondition, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )
      validateStmtBlock(
        statement.body, currentModule, locals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skFor:
      var loopLocals = locals
      if not statement.forInitializer.isNil:
        validateStmtBlock(
          @[statement.forInitializer], currentModule, loopLocals,
          typeParameters, classes, functions, modules, rootModule
        )
        if statement.forInitializer.kind == skVar:
          loopLocals.incl statement.forInitializer.name
      validateExpr(
        statement.forCondition, currentModule, loopLocals, typeParameters,
        classes, functions, modules, rootModule
      )
      if not statement.forUpdate.isNil:
        validateStmtBlock(
          @[statement.forUpdate], currentModule, loopLocals,
          typeParameters, classes, functions, modules, rootModule
        )
      validateStmtBlock(
        statement.forBody, currentModule, loopLocals, typeParameters,
        classes, functions, modules, rootModule
      )

    of skBreak, skContinue:
      discard

## Documents the validateCallable module helper behavior.
proc validateCallable(
  source: FunctionDecl,
  currentModule: string,
  typeParameters: HashSet[string],
  classes: ClassRegistry,
  functions: FunctionOwnerRegistry,
  modules: ModuleRegistry,
  rootModule: string,
  includeSelf: bool
) =
  var locals = initHashSet[string]()
  if includeSelf:
    locals.incl "self"

  for parameter in source.parameters:
    validateTypeRef(
      parameter.typeRef, currentModule, typeParameters, classes
    )
    locals.incl parameter.name

  if source.result.kind == frrSingle:
    validateTypeRef(
      source.result.typeRef, currentModule, typeParameters, classes
    )

  validateStmtBlock(
    source.body, currentModule, locals, typeParameters,
    classes, functions, modules, rootModule
  )

## Documents the validateModuleArchitecture module helper behavior.
proc validateModuleArchitecture*(
  source: Program,
  project: projectModel.EidoProject
) =
  if project.modules.len == 0:
    return

  var modules = initTable[string, moduleModel.ModuleSpec]()
  for moduleSpec in project.modules:
    modules[moduleSpec.canonicalName] = moduleSpec

  var classes = initTable[string, ClassDecl]()
  for sourceClass in source.classes:
    if sourceClass.name in classes:
      failAt(
        sourceClass.span,
        "module-aware v0 currently requires project-unique class names; duplicate '" &
          sourceClass.name & "'"
      )
    classes[sourceClass.name] = sourceClass

  var functions = initTable[string, string]()
  for sourceFunction in source.functions:
    if sourceFunction.name in functions:
      failAt(
        sourceFunction.span,
        "module-aware v0 currently requires project-unique top-level function names; duplicate '" &
          sourceFunction.name & "'"
      )
    functions[sourceFunction.name] = sourceFunction.moduleName

  validateManifestSurfaces(
    modules,
    classes,
    functions,
    project.rootModule
  )

  for sourceClass in source.classes:
    var typeParameters = initHashSet[string]()
    for typeParameter in sourceClass.typeParameters:
      typeParameters.incl typeParameter.name

    for field in sourceClass.fields:
      validateTypeRef(
        field.typeRef,
        sourceClass.moduleName,
        typeParameters,
        classes
      )

    for methodDecl in sourceClass.methods:
      validateCallable(
        methodDecl,
        sourceClass.moduleName,
        typeParameters,
        classes,
        functions,
        modules,
        project.rootModule,
        true
      )

  var noTypeParameters = initHashSet[string]()
  for sourceFunction in source.functions:
    validateCallable(
      sourceFunction,
      sourceFunction.moduleName,
      noTypeParameters,
      classes,
      functions,
      modules,
      project.rootModule,
      false
    )
