## Enforces module architecture and rewrites module-project references to canonical identities.
## The returned Program is ready for ordinary semantic analysis without source-level namespace ambiguity.

import std/[sets, strutils, tables]
import ../../diagnostics/errors
import ../../frontend/ast/[declarations, expressions, program, statements, type_references]
import ../../source/span
import ../../project/model as projectModel
import ../../project/modules/model as moduleModel
import ../../types/method_kind
import ../../types/storage
import ../analysis/method_classification

type
  ClassRegistry = Table[string, ClassDecl]
  InterfaceRegistry = Table[string, InterfaceDecl]
  FunctionOwnerRegistry = Table[string, string]
  ModuleRegistry = Table[string, moduleModel.ModuleSpec]
  SurfaceRegistry = Table[string, HashSet[string]]

## Builds the canonical semantic identity for one module-owned declaration.
proc declarationKey(moduleName, localName: string): string =
  if moduleName.len == 0:
    localName
  else:
    moduleName & "." & localName

## Returns the source-local declaration name from a canonical identity.
proc declarationLocalName(canonicalName: string): string =
  let separator = canonicalName.rfind('.')
  if separator < 0: canonicalName else: canonicalName[separator + 1 .. ^1]

## Reports whether one class can serve as a module-level static API root.
## Static API classes carry no instance state and every Eido-bodied method is self-free.
proc isStaticOnly(source: ClassDecl): bool =
  if source.fields.len != 0:
    return false
  for methodDecl in source.methods:
    if not methodDecl.isNative and inferMethodKind(methodDecl) != mkStatic:
      return false
  true

include validation/visibility
include validation/public_surface
include validation/qualification
include validation/interfaces
include validation/source_usage

## Builds canonical declaration registries while rejecting collisions only inside one module.
proc collectModuleDeclarations(
  source: Program,
  classes: var ClassRegistry,
  interfaces: var InterfaceRegistry,
  functions: var FunctionOwnerRegistry
) =
  for sourceInterface in source.interfaces:
    let key = declarationKey(
      sourceInterface.moduleName,
      declarationLocalName(sourceInterface.name)
    )
    if key in interfaces or key in classes:
      failAt(
        sourceInterface.span,
        "duplicate nominal declaration '" &
          declarationLocalName(sourceInterface.name) &
          "' in module '" & sourceInterface.moduleName & "'"
      )
    interfaces[key] = sourceInterface

  for sourceClass in source.classes:
    if isStorageTypeConstructor(sourceClass.name):
      failAt(
        sourceClass.span,
        "type name 'Storage' is reserved by the Eido toolchain"
      )
    let key = declarationKey(
      sourceClass.moduleName,
      declarationLocalName(sourceClass.name)
    )
    if key in classes or key in interfaces:
      failAt(
        sourceClass.span,
        "duplicate nominal declaration '" &
          declarationLocalName(sourceClass.name) &
          "' in module '" & sourceClass.moduleName & "'"
      )
    classes[key] = sourceClass

  for sourceFunction in source.functions:
    let key = declarationKey(
      sourceFunction.moduleName,
      declarationLocalName(sourceFunction.name)
    )
    if key in functions:
      failAt(
        sourceFunction.span,
        "duplicate function '" &
          declarationLocalName(sourceFunction.name) &
          "' in module '" & sourceFunction.moduleName & "'"
      )
    functions[key] = sourceFunction.moduleName

## Validates and canonicalizes one parsed module project.
proc resolveModuleArchitecture*(
  source: var Program,
  project: projectModel.EidoProject
) =
  if project.modules.len == 0:
    return

  var modules = initTable[string, moduleModel.ModuleSpec]()
  for moduleSpec in project.modules:
    modules[moduleSpec.canonicalName] = moduleSpec

  var classes = initTable[string, ClassDecl]()
  var interfaces = initTable[string, InterfaceDecl]()
  var functions = initTable[string, string]()
  collectModuleDeclarations(source, classes, interfaces, functions)

  validateManifestSurfaces(
    modules,
    classes,
    interfaces,
    functions,
    project.rootModule
  )

  let publicSurfaces = buildPublicSurfaces(
    modules,
    classes,
    interfaces,
    project.rootModule
  )
  let adoptedSurfaces = buildAdoptedSurfaces(
    modules,
    classes,
    interfaces,
    publicSurfaces,
    project.rootModule
  )
  let providedSurfaces = buildProvidedSurfaces(
    modules,
    classes,
    interfaces,
    publicSurfaces,
    project.rootModule
  )

  qualifyModuleProgram(
    source,
    modules,
    classes,
    interfaces,
    functions,
    publicSurfaces,
    adoptedSurfaces,
    providedSurfaces,
    project.rootModule
  )

  # Rebuild registries from the canonicalized AST before semantic architecture checks.
  classes = initTable[string, ClassDecl]()
  interfaces = initTable[string, InterfaceDecl]()
  functions = initTable[string, string]()
  collectModuleDeclarations(source, classes, interfaces, functions)

  validateInterfacePurpose(
    interfaces,
    publicSurfaces,
    adoptedSurfaces,
    providedSurfaces
  )
  validateInterfaceOwnership(
    classes,
    interfaces,
    modules,
    publicSurfaces,
    adoptedSurfaces,
    providedSurfaces
  )
  validateProviders(
    classes,
    interfaces,
    modules
  )

  var noTypeParameters = initHashSet[string]()
  for sourceInterface in source.interfaces:
    for methodDecl in sourceInterface.methods:
      validateCallable(
        methodDecl,
        sourceInterface.moduleName,
        noTypeParameters,
        classes,
        interfaces,
        functions,
        modules,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        true
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
        classes,
        interfaces,
        modules,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces
      )

    var invariantLocals = initHashSet[string]()
    invariantLocals.incl "self"
    for clause in sourceClass.invariants:
      validateExpr(
        clause, sourceClass.moduleName, invariantLocals, typeParameters,
        classes, interfaces, functions, modules,
        publicSurfaces, adoptedSurfaces, providedSurfaces
      )

    for methodDecl in sourceClass.methods:
      validateCallable(
        methodDecl,
        sourceClass.moduleName,
        typeParameters,
        classes,
        interfaces,
        functions,
        modules,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        true
      )

  for sourceFunction in source.functions:
    validateCallable(
      sourceFunction,
      sourceFunction.moduleName,
      noTypeParameters,
      classes,
      interfaces,
      functions,
      modules,
      publicSurfaces,
      adoptedSurfaces,
      providedSurfaces,
      false
    )

## Preserves the previous validation-only API for callers that do not need the rewritten AST.
proc validateModuleArchitecture*(
  source: Program,
  project: projectModel.EidoProject
) =
  var resolved = source
  resolveModuleArchitecture(resolved, project)
