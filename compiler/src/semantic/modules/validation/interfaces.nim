## Validates interface/module architecture after canonical module name resolution.

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
      let key = declarationKey(target.moduleName, target.symbolName)

      if key in functions:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "top-level functions cannot be exported from modules"
        )

      if key in interfaces:
        continue

      if key notin classes:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "unknown exported declaration '" & exportRef & "'"
        )

      let sourceClass = classes[key]
      if not isStaticOnly(sourceClass):
        failAt(
          sourceClass.span,
          "module export '" & exportRef &
            "' must be an interface or static-only class; " &
            "concrete instance classes cannot be export roots"
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

## Verifies every interface declaration participates in an architectural surface.
proc validateInterfacePurpose(
  interfaces: InterfaceRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
) =
  for interfaceName, sourceInterface in interfaces:
    var architectural = false

    for _, surface in publicSurfaces:
      if interfaceName in surface:
        architectural = true
        break

    if not architectural:
      for _, surface in adoptedSurfaces:
        if interfaceName in surface:
          architectural = true
          break

    if not architectural:
      for _, surface in providedSurfaces:
        if interfaceName in surface:
          architectural = true
          break

    if not architectural:
      failAt(
        sourceInterface.span,
        "interface '" & declarationLocalName(interfaceName) &
          "' must participate in an exported, adopted, or provided module API surface"
      )

## Validates owner-local, explicitly exported interface permissions.
proc validateExternalImplementationPermissions(
  modules: ModuleRegistry,
  interfaces: InterfaceRegistry
) =
  for moduleName, moduleSpec in modules:
    var seen = initHashSet[string]()
    for entry in moduleSpec.allowsExternalImplementation:
      let key = declarationKey(moduleName, entry)
      if key notin interfaces or interfaces[key].moduleName != moduleName:
        failAt(moduleSpec.manifestPath, 1, 1,
          "allowsExternalImplementation must name an interface owned by the module: '" & entry & "'")
      if entry notin moduleSpec.exports:
        failAt(moduleSpec.manifestPath, 1, 1,
          "allowsExternalImplementation requires an explicitly exported interface: '" & entry & "'")
      if key in seen:
        failAt(moduleSpec.manifestPath, 1, 1,
          "duplicate allowsExternalImplementation entry '" & entry & "'")
      seen.incl key

## Checks each inherited contract independently: a permitted child cannot
## grant permission to implement a closed ancestor owned by another module.
proc requireImplementationPermission(
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry,
  sourceClass: ClassDecl,
  implemented: string,
  seen: var HashSet[string]
) =
  if implemented in seen or implemented notin interfaces:
    return
  seen.incl implemented
  let contract = interfaces[implemented]
  let owner = contract.moduleName
  if not isSameOrDescendant(owner, sourceClass.moduleName) and
      (owner notin modules or
        declarationLocalName(implemented) notin modules[owner].allowsExternalImplementation):
    failAt(
      sourceClass.span,
      "class '" & declarationLocalName(sourceClass.name) &
        "' cannot implement closed interface '" &
        declarationLocalName(implemented) &
        "' outside its owning module family '" & owner & "'"
    )
  for parent in contract.extends:
    requireImplementationPermission(interfaces, modules, sourceClass, parent, seen)

## Verifies closed interface extension and authorized class implementation.
## References must already be canonical when this pass runs.
proc validateInterfaceOwnership(
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry
) =
  for _, sourceInterface in interfaces:
    for parent in sourceInterface.extends:
      if parent notin interfaces:
        continue

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

      let owner = interfaces[parent].moduleName
      if not isSameOrDescendant(owner, sourceInterface.moduleName):
        failAt(
          sourceInterface.span,
          "interface '" & declarationLocalName(sourceInterface.name) &
            "' cannot extend closed interface '" &
            declarationLocalName(parent) &
            "' outside its owning module family '" & owner & "'"
        )

  for _, sourceClass in classes:
    for implementedRef in sourceClass.implements:
      let implemented = implementedRef.name
      if implemented notin interfaces:
        continue

      requireInterfaceVisibility(
        modules,
        interfaces,
        publicSurfaces,
        adoptedSurfaces,
        providedSurfaces,
        sourceClass.moduleName,
        implemented,
        sourceClass.span.sourcePath,
        sourceClass.span.line,
        sourceClass.span.column
      )

      var seen = initHashSet[string]()
      requireImplementationPermission(interfaces, modules, sourceClass, implemented, seen)

## Verifies each provides declaration names a parent-owned interface and a real provider.
proc validateProviders(
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  modules: ModuleRegistry
) =
  for _, moduleSpec in modules:
    for provision in moduleSpec.provides:
      let contractKey = declarationKey(
        moduleSpec.canonicalName,
        provision.contract
      )

      if contractKey notin interfaces:
        failAt(
          moduleSpec.manifestPath, 1, 1,
          "provided contract '" & provision.contract & "' is not an interface"
        )

      var found = false
      for _, sourceClass in classes:
        if not isSameOrDescendant(
          provision.providerModule,
          sourceClass.moduleName
        ):
          continue

        for implementedRef in sourceClass.implements:
          if interfaceExtends(
            interfaces,
            implementedRef.name,
            contractKey
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
