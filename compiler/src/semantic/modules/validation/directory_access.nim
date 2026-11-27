## Internal directory adoption is separate from child-module API propagation.
## The first relative directory is a grouping boundary, not a nominal namespace.

## A real descendant module keeps the original child-export adoption rules.
## All other entries are local directory adoption spellings.
proc isDirectoryAdoption(modules: ModuleRegistry, rootModule: string,
    owner: moduleModel.ModuleSpec, reference: string): bool =
  let separator = reference.rfind('.')
  if separator <= 0: return true
  let qualifier = reference[0 ..< separator]
  for candidate in moduleReferenceCandidates(modules, rootModule, owner.canonicalName, qualifier):
    if isDescendant(owner.canonicalName, candidate): return false
  true

## Rejects unknown or incorrectly located directory adoption declarations.
## Unlike module exports, these roots can be instance classes or functions.
proc validateDirectoryAdoptions(source: Program, modules: ModuleRegistry,
    classes: ClassRegistry, interfaces: InterfaceRegistry,
    functions: FunctionOwnerRegistry, rootModule: string): HashSet[string] =
  result = initHashSet[string]()
  for _, spec in modules:
    var seen = initHashSet[string]()
    let policyNames = if spec.adopts.len > 0 and spec.policySources.len > 0:
      policyDirectoryAdoptionNames(spec)
    else: initHashSet[string]()
    for reference in spec.adopts:
      if not isDirectoryAdoption(modules, rootModule, spec, reference): continue
      if reference in seen:
        failAt(spec.manifestPath, 1, 1, "duplicate directory adoption '" & reference & "'")
      seen.incl reference
      let localName = declarationLocalName(reference)
      let key = declarationKey(spec.canonicalName, localName)
      var expected: seq[string]
      var matched = false

      template checkDeclaration(span: SourceSpan, interfaceDeclaration: bool) =
        let name = directoryAdoptionName(spec, span.sourcePath, localName)
        if name notin expected: expected.add name
        if reference == name:
          matched = true
          if interfaceDeclaration: result.incl key

      if key in classes: checkDeclaration(classes[key].span, false)
      if key in interfaces: checkDeclaration(interfaces[key].span, true)
      if key in functions: checkDeclaration(functions[key].span, false)
      for layout in source.layouts:
        if layout.moduleName == spec.canonicalName and layout.name == localName:
          checkDeclaration(layout.span, false)
      if matched or reference in policyNames: continue
      # Hidden runtime target sources are deliberately absent in the base pass.
      if spec.policySources.len > 0 and spec.sourcePaths.len == 0: continue
      if expected.len > 0:
        failAt(spec.manifestPath, 1, 1, "directory adoption '" & reference &
          "' must identify its owning directory as '" & expected.join("' or '") & "'")
      failAt(spec.manifestPath, 1, 1, "unknown directory adoption '" & reference & "'")

## Enforces a direct declaration reference even when no explicit import exists.
proc requireDirectoryAccess(modules: ModuleRegistry, currentModule, key: string,
    target, consumer: SourceSpan) =
  if currentModule notin modules or target.sourcePath == consumer.sourcePath: return
  let spec = modules[currentModule]
  if sourceDirectoryGroup(spec, target.sourcePath) ==
      sourceDirectoryGroup(spec, consumer.sourcePath): return
  let adoption = directoryAdoptionName(spec, target.sourcePath, declarationLocalName(key))
  if adoption notin spec.adopts or not isDirectoryAdoption(modules, "", spec, adoption):
    failAt(consumer, "cross-directory access to '" & key &
      "' requires adopts: " & adoption & " in " & spec.manifestPath)

## Applies internal access only to declarations owned by the requesting module.
proc requireNominalDirectoryAccess(modules: ModuleRegistry, classes: ClassRegistry,
    interfaces: InterfaceRegistry, currentModule, key: string, consumer: SourceSpan) =
  if key in classes and classes[key].moduleName == currentModule:
    requireDirectoryAccess(modules, currentModule, key, classes[key].span, consumer)
  elif key in interfaces and interfaces[key].moduleName == currentModule:
    requireDirectoryAccess(modules, currentModule, key, interfaces[key].span, consumer)
