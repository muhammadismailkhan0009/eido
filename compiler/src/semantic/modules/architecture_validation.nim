## Enforces module architecture before ordinary Eido semantic analysis.
## Modules control source ownership, visibility, interface ownership, providers, and dependencies.

import std/[sets, strutils, tables]
import ../../diagnostics/errors
import ../../frontend/ast/[declarations, expressions, program, statements, type_references]
import ../../project/model as projectModel
import ../../project/modules/model as moduleModel

type
  ClassRegistry = Table[string, ClassDecl]
  InterfaceRegistry = Table[string, InterfaceDecl]
  FunctionOwnerRegistry = Table[string, string]
  ModuleRegistry = Table[string, moduleModel.ModuleSpec]
  SurfaceRegistry = Table[string, HashSet[string]]


include validation/visibility
include validation/public_surface
include validation/interfaces
include validation/source_usage

## Validates interfaces/classes/functions against the loaded module graph.
proc validateModuleArchitecture*(
  source: Program,
  project: projectModel.EidoProject
) =
  if project.modules.len == 0:
    return

  var modules = initTable[string, moduleModel.ModuleSpec]()
  for moduleSpec in project.modules:
    modules[moduleSpec.canonicalName] = moduleSpec

  var interfaces = initTable[string, InterfaceDecl]()
  for sourceInterface in source.interfaces:
    if sourceInterface.name in interfaces:
      failAt(
        sourceInterface.span,
        "module-aware v0 currently requires project-unique interface names; duplicate '" &
          sourceInterface.name & "'"
      )
    interfaces[sourceInterface.name] = sourceInterface

  var classes = initTable[string, ClassDecl]()
  for sourceClass in source.classes:
    if sourceClass.name in classes or sourceClass.name in interfaces:
      failAt(
        sourceClass.span,
        "module-aware v0 currently requires project-unique nominal names; duplicate '" &
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
    project.rootModule
  )
  let providedSurfaces = buildProvidedSurfaces(
    modules,
    classes,
    interfaces
  )

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
    for parent in sourceInterface.extends:
      if parent in interfaces:
        requireInterfaceVisibility(
          modules,
          interfaces,
          publicSurfaces,
          adoptedSurfaces,
          providedSurfaces,
          sourceInterface.moduleName,
          parent,
          sourceInterface.span.sourcePath,
          sourceInterface.span.line,
          sourceInterface.span.column
        )
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
        false
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
