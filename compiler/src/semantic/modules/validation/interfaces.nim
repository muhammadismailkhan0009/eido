## Reports whether one interface transitively extends another, including identity.
proc interfaceExtends(
  interfaces: InterfaceRegistry,
  childName, ancestorName: string
): bool =
  if childName == ancestorName:
    return true
  if childName notin interfaces:
    return false

  for parent in interfaces[childName].extends:
    if interfaceExtends(interfaces, parent, ancestorName):
      return true
  false

## Validates that manifest exports/adoptions point at legal declaration kinds.
proc validateManifestSurfaces(
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  rootModule: string
) =
  for _, moduleSpec in modules:
    for exportRef in moduleSpec.exports:
      let target = resolveChildExport(
        modules,
        rootModule,
        moduleSpec,
        exportRef
      )

      if target.symbolName in functions:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "top-level functions cannot be exported from modules"
        )

      if target.symbolName in interfaces:
        let sourceInterface = interfaces[target.symbolName]
        if sourceInterface.moduleName != target.moduleName:
          failAt(
            moduleSpec.manifestPath, 1, 1,
            "export '" & exportRef & "' resolves to interface owned by '" &
              sourceInterface.moduleName & "'"
          )
        continue

      if target.symbolName notin classes:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "unknown exported declaration '" & exportRef & "'"
        )

      let sourceClass = classes[target.symbolName]
      if sourceClass.moduleName != target.moduleName:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "export '" & exportRef & "' resolves to class owned by '" &
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
        rootModule,
        moduleSpec,
        adoption
      )
      if target.moduleName == moduleSpec.canonicalName:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "adopt must reference a child module export"
        )

## Verifies every interface declaration participates in exports or provides.
proc validateInterfacePurpose(
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry,
  rootModule: string
) =
  for interfaceName, sourceInterface in interfaces:
    let owner = modules[sourceInterface.moduleName]
    var architectural = false

    for exportRef in owner.exports:
      let target = exportedSymbol(
        modules,
        rootModule,
        owner,
        exportRef
      )
      if target.moduleName == sourceInterface.moduleName and
          target.symbolName == interfaceName:
        architectural = true
        break

    if not architectural:
      for provision in owner.provides:
        if provision.contract == interfaceName:
          architectural = true
          break

    if not architectural:
      failAt(
        sourceInterface.span,
        "interface '" & interfaceName &
          "' must be exported or used as a parent-owned provided contract"
      )

## Verifies closed interface extension and class implementation ownership.
proc validateInterfaceOwnership(
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry,
  rootModule: string
) =
  for _, sourceInterface in interfaces:
    for parent in sourceInterface.extends:
      if parent notin interfaces:
        continue

      requireInterfaceVisibility(
        modules,
        interfaces,
        rootModule,
        sourceInterface.moduleName,
        parent,
        sourceInterface.span.sourcePath,
        sourceInterface.span.line,
        sourceInterface.span.column
      )

      let owner = interfaces[parent].moduleName
      if not isSameOrDescendant(owner, sourceInterface.moduleName):
        failAt(
          sourceInterface.span,
          "interface '" & sourceInterface.name &
            "' cannot extend closed interface '" & parent &
            "' outside its owning module family '" & owner & "'"
        )

  for _, sourceClass in classes:
    for implemented in sourceClass.implements:
      if implemented notin interfaces:
        continue

      requireInterfaceVisibility(
        modules,
        interfaces,
        rootModule,
        sourceClass.moduleName,
        implemented,
        sourceClass.span.sourcePath,
        sourceClass.span.line,
        sourceClass.span.column
      )

      let owner = interfaces[implemented].moduleName
      if not isSameOrDescendant(owner, sourceClass.moduleName):
        failAt(
          sourceClass.span,
          "class '" & sourceClass.name &
            "' cannot implement closed interface '" & implemented &
            "' outside its owning module family '" & owner & "'"
        )

## Verifies each provides declaration names a parent-owned interface and a real provider.
proc validateProviders(
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry
) =
  for _, moduleSpec in modules:
    for provision in moduleSpec.provides:
      if provision.contract notin interfaces:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "provided contract '" & provision.contract & "' is not an interface"
        )

      let contract = interfaces[provision.contract]
      if contract.moduleName != moduleSpec.canonicalName:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "provided contract '" & provision.contract &
            "' must be owned by parent module '" &
            moduleSpec.canonicalName & "'"
        )

      var found = false
      for _, sourceClass in classes:
        if not isSameOrDescendant(
          provision.providerModule,
          sourceClass.moduleName
        ):
          continue

        for implemented in sourceClass.implements:
          if interfaceExtends(
            interfaces,
            implemented,
            provision.contract
          ):
            found = true
            break
        if found:
          break

      if not found:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "child provider '" & provision.providerModule &
            "' does not implement contract '" & provision.contract & "'"
        )

