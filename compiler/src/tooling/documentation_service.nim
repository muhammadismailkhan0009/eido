## Builds protocol-neutral API documentation from the same module and semantic
## declarations used by the compiler.
##
## Visibility is derived from module public-surface closure. Documentation
## comments remain tooling metadata and therefore do not enter AST/HIR semantics.

import std/[algorithm, sets, strutils, tables]
import ../frontend/ast/[declarations, program, type_references]
import ../frontend/parser/project_parser
import ../project/model
import ../semantic/analysis/[method_classification, program_analysis]
import ../semantic/modules/architecture_validation
import ../source/[source_unit, span]
import ../types/method_kind
import comment_service
import documentation_model

## Returns the source-local name from a canonical declaration identity.
proc localName(name: string): string =
  let separator = name.rfind('.')
  if separator < 0: name else: name[separator + 1 .. ^1]

## Renders one source-facing type reference for API signatures.
proc typeRefText(typeRef: TypeRef): string =
  result = localName(typeRef.name)
  if typeRef.arguments.len > 0:
    result.add "<"
    for index, argument in typeRef.arguments:
      if index > 0:
        result.add ", "
      result.add typeRefText(argument)
    result.add ">"
  if typeRef.isOptional:
    result.add "?"

## Renders the optional return-type suffix of one callable signature.
proc resultSuffix(callable: FunctionDecl): string =
  if callable.result.kind == frrSingle:
    " returns " & typeRefText(callable.result.typeRef)
  else:
    ""

## Renders one callable parameter list using Eido source spelling.
proc parameterText(parameters: seq[Parameter]): string =
  for index, parameter in parameters:
    if index > 0:
      result.add ", "
    result.add typeRefText(parameter.typeRef) & " " & parameter.name

## Renders a source-facing function or method signature.
proc callableSignature(callable: FunctionDecl): string =
  let prefix = if callable.isNative: "native " else: ""
  prefix & "function " & localName(callable.name) & "(" &
    parameterText(callable.parameters) & ")" & resultSuffix(callable)

## Renders the declaration header of one documented class.
proc classSignature(source: ClassDecl): string =
  result = "class " & localName(source.name)
  if source.typeParameters.len > 0:
    result.add "<"
    for index, parameter in source.typeParameters:
      if index > 0:
        result.add ", "
      result.add parameter.name
    result.add ">"

  if source.implements.len > 0:
    result.add " implements "
    for index, interfaceName in source.implements:
      if index > 0:
        result.add ", "
      result.add localName(interfaceName)

## Renders the declaration header of one documented interface.
proc interfaceSignature(source: InterfaceDecl): string =
  result = "interface " & localName(source.name)
  if source.extends.len > 0:
    result.add " extends "
    for index, parentName in source.extends:
      if index > 0:
        result.add ", "
      result.add localName(parentName)

## Finds the exact source text belonging to one project source path.
proc sourceText(project: EidoProject, sourcePath: string): string =
  for source in project.sources:
    if source.path == sourcePath:
      return source.text
  ""

## Reads the attached `///` block for one declaration span.
proc sourceDocumentation(
  project: EidoProject,
  declarationSpan: SourceSpan
): string =
  let text = sourceText(project, declarationSpan.sourcePath)
  if text.len == 0:
    return ""
  documentationCommentBefore(text, declarationSpan.startOffset)

## Lists every module whose public surface contains one canonical declaration.
proc visibleFrom(
  architecture: ModuleArchitectureInfo,
  canonicalName: string
): seq[string] =
  for moduleName, surface in architecture.publicSurfaces:
    if canonicalName in surface:
      result.add moduleName
  result.sort()

## Maps public-surface reachability to documentation visibility.
proc declarationVisibility(visibleModules: seq[string]): DocumentationVisibility =
  if visibleModules.len > 0: dvPublic else: dvInternal

## Builds documented field and method entries for one class.
proc classMembers(
  project: EidoProject,
  source: ClassDecl
): seq[DocumentationMember] =
  for field in source.fields:
    let owner = localName(source.name)
    let signature =
      if field.isClassOwned:
        typeRefText(field.typeRef) & " " & owner & "." & field.name
      else:
        typeRefText(field.typeRef) & " " & field.name

    result.add DocumentationMember(
      name: field.name,
      signature: signature,
      documentation: sourceDocumentation(project, field.span),
      kind: dmkField,
      isStatic: field.isClassOwned,
      isNative: false
    )

  for methodDecl in source.methods:
    let isStatic =
      methodDecl.isNative or inferMethodKind(methodDecl) == mkStatic
    result.add DocumentationMember(
      name: methodDecl.name,
      signature: callableSignature(methodDecl),
      documentation: sourceDocumentation(project, methodDecl.span),
      kind: dmkMethod,
      isStatic: isStatic,
      isNative: methodDecl.isNative
    )

## Builds documented method entries for one interface.
proc interfaceMembers(
  project: EidoProject,
  source: InterfaceDecl
): seq[DocumentationMember] =
  for methodDecl in source.methods:
    result.add DocumentationMember(
      name: methodDecl.name,
      signature: callableSignature(methodDecl),
      documentation: sourceDocumentation(project, methodDecl.span),
      kind: dmkMethod,
      isStatic: false,
      isNative: false
    )

## Builds all source declaration records owned by one module.
proc sourceDeclarations(
  project: EidoProject,
  resolved: Program,
  architecture: ModuleArchitectureInfo,
  moduleName: string
): seq[DocumentationDeclaration] =
  for sourceClass in resolved.classes:
    if sourceClass.moduleName != moduleName:
      continue
    let visibleModules = visibleFrom(architecture, sourceClass.name)
    result.add DocumentationDeclaration(
      name: localName(sourceClass.name),
      canonicalName: sourceClass.name,
      moduleName: moduleName,
      sourcePath: sourceClass.span.sourcePath,
      signature: classSignature(sourceClass),
      documentation: sourceDocumentation(project, sourceClass.span),
      kind: ddkClass,
      visibility: declarationVisibility(visibleModules),
      origin: doSource,
      visibleFrom: visibleModules,
      members: classMembers(project, sourceClass)
    )

  for sourceInterface in resolved.interfaces:
    if sourceInterface.moduleName != moduleName:
      continue
    let visibleModules = visibleFrom(architecture, sourceInterface.name)
    result.add DocumentationDeclaration(
      name: localName(sourceInterface.name),
      canonicalName: sourceInterface.name,
      moduleName: moduleName,
      sourcePath: sourceInterface.span.sourcePath,
      signature: interfaceSignature(sourceInterface),
      documentation: sourceDocumentation(project, sourceInterface.span),
      kind: ddkInterface,
      visibility: declarationVisibility(visibleModules),
      origin: doSource,
      visibleFrom: visibleModules,
      members: interfaceMembers(project, sourceInterface)
    )

  for sourceFunction in resolved.functions:
    if sourceFunction.moduleName != moduleName:
      continue
    result.add DocumentationDeclaration(
      name: localName(sourceFunction.name),
      canonicalName: sourceFunction.name,
      moduleName: moduleName,
      sourcePath: sourceFunction.span.sourcePath,
      signature: callableSignature(sourceFunction),
      documentation: sourceDocumentation(project, sourceFunction.span),
      kind: ddkFunction,
      visibility: dvInternal,
      origin: doSource,
      visibleFrom: @[]
    )

  result.sort(proc(left, right: DocumentationDeclaration): int =
    cmp(left.name, right.name)
  )

## Builds a complete documentation reference for one module-aware Eido project.
## The project is semantically checked as a library so documentation does not
## require an executable main function.
proc buildDocumentationReference*(project: EidoProject): DocumentationReference =
  var resolved = parseProject(project)
  let architecture = resolveModuleArchitectureWithInfo(resolved, project)
  discard analyzeProgram(resolved, ptLibrary)

  result.projectName = project.rootModule
  for moduleSpec in project.modules:
    result.modules.add DocumentationModule(
      name: moduleSpec.canonicalName,
      isSdk: moduleSpec.canonicalName == "eido.stdlib" or
        moduleSpec.canonicalName.startsWith("eido.stdlib."),
      declarations: sourceDeclarations(
        project,
        resolved,
        architecture,
        moduleSpec.canonicalName
      )
    )

  result.modules.sort(proc(left, right: DocumentationModule): int =
    cmp(left.name, right.name)
  )
