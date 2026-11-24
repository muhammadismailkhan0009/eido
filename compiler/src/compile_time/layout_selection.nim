## Resolves the intrinsic compile-time LayoutPolicy.select(class, layout) calls.
##
## Each concrete class receives one active validated layout. A template-wide
## selection applies to all already-instantiated concrete specializations;
## an explicit specialization overrides that template-level default.
## Equal-specificity conflicting selections are compile errors.

import std/[strutils, tables, sets]
import ../diagnostics/errors
import ../hir/program as hirProgram
import ../hir/declarations as hirDeclarations
import model

## Excludes any generic arguments while finding a nominal's module boundary.
proc nominalBase(name: string): string =
  let bracket = name.find('<')
  if bracket >= 0: name[0 ..< bracket] else: name

## Removes module qualifiers from the outer nominal and generic arguments.
## This lets module-local selection strings use Box<Family> rather than
## requiring Box<app.Family>, while still checking ambiguous matches.
proc simplifiedName(name: string): string =
  var token = ""
  template flushToken() =
    if token.len > 0:
      let dot = token.rfind('.')
      if dot >= 0: result.add token[dot + 1 .. ^1]
      else: result.add token
      token.setLen(0)

  for character in name:
    if character in {'<', '>', ',', '?', ' '}:
      flushToken()
      if character != ' ':
        result.add character
    else:
      token.add character
  flushToken()

## Returns the nominal name without its outer module prefix.
proc nominalLocalName(name: string): string =
  let base = nominalBase(name)
  let dot = base.rfind('.')
  if dot < 0: name else: name[dot + 1 .. ^1]

## Matches qualified or local nominal names against a selection.
proc nameMatches(candidate, requested, moduleName: string): bool =
  candidate == requested or
    candidate == moduleName & "." & requested or
    nominalLocalName(candidate) == requested or
    simplifiedName(candidate) == requested or
    (moduleName.len > 0 and
      candidate.startsWith(moduleName & ".") and
      moduleName & "." & simplifiedName(candidate) == requested)

## Matches a generic template request to a concrete specialization.
proc templateMatches(candidate, requested, moduleName: string): bool =
  '<' notin requested and '<' in candidate and
    (nominalBase(candidate) == requested or
      nominalBase(candidate) == moduleName & "." & requested or
      nominalBase(nominalLocalName(candidate)) == requested)

## Ranks concrete selections above generic template defaults.
proc specificity(candidate, requested, moduleName: string): int =
  if nameMatches(candidate, requested, moduleName): 2
  elif templateMatches(candidate, requested, moduleName): 1
  else: 0

## Returns the module owning the outer nominal.
proc owningModule(candidate: string): string =
  let base = nominalBase(candidate)
  let lastDot = base.rfind('.')
  if lastDot >= 0: base[0 ..< lastDot] else: ""

## Resolves a caller's unqualified class reference locally if possible.
## An explicit qualified request may of course target another module.
proc matchedClasses(
  metadata: CompileTimeMemoryMetadata,
  selection: hirDeclarations.HirLayoutSelection
): seq[tuple[index, specificity: int]] =
  var allMatches: seq[tuple[index, specificity: int]]
  var localMatches: seq[tuple[index, specificity: int]]
  var modules = initHashSet[string]()
  for index, classMetadata in metadata.types:
    let level = specificity(
      classMetadata.className, selection.targetName, selection.moduleName
    )
    if level == 0:
      continue
    allMatches.add (index, level)
    modules.incl owningModule(classMetadata.className)
    if owningModule(classMetadata.className) == selection.moduleName:
      localMatches.add (index, level)

  if allMatches.len == 0:
    failAt(selection.span,
      "LayoutPolicy.select references unknown or uninstantiated class '" &
        selection.targetName & "'")

  if selection.moduleName.len > 0 and
      nominalBase(selection.targetName).find('.') < 0 and localMatches.len > 0:
    return localMatches

  if modules.len > 1 and nominalBase(selection.targetName).find('.') < 0:
    failAt(selection.span,
      "ambiguous LayoutPolicy class '" & selection.targetName &
        "'; use its fully qualified name")
  allMatches

## Finds exactly one layout for one concrete class with its requested name.
proc resolveNamedLayout(
  metadata: CompileTimeMemoryMetadata,
  selection: hirDeclarations.HirLayoutSelection,
  className: string
): int =
  var candidates: seq[int]
  var localCandidates: seq[int]
  for index, named in metadata.namedLayouts:
    if named.layout.className != className:
      continue
    if specificity(named.name, selection.layoutName, selection.moduleName) == 0:
      continue
    candidates.add index
    if owningModule(named.name) == selection.moduleName:
      localCandidates.add index

  if nominalBase(selection.layoutName).find('.') < 0 and
      selection.moduleName.len > 0 and localCandidates.len > 0:
    candidates = localCandidates

  if candidates.len == 0:
    failAt(selection.span,
      "layout '" & selection.layoutName & "' does not exist for class '" &
        className & "'")
  if candidates.len > 1:
    failAt(selection.span,
      "ambiguous layout '" & selection.layoutName & "' for class '" &
        className & "'; use a fully qualified layout name")
  candidates[0]

## Applies a selected layout to the *single* canonical type metadata table.
## Constructors, inline Storage, field access and GC/RC all read this same table.
proc applyLayoutSelections*(
  program: hirProgram.HirProgram,
  metadata: var CompileTimeMemoryMetadata
) =
  var chosen = initTable[string, tuple[name: string, specificity: int]]()

  for selection in program.layoutSelections:
    let classes = metadata.matchedClasses(selection)
    for matched in classes:
      let className = metadata.types[matched.index].className
      let layoutId = metadata.resolveNamedLayout(selection, className)
      let named = metadata.namedLayouts[layoutId]
      if className in chosen:
        let earlier = chosen[className]
        if matched.specificity < earlier.specificity:
          continue  # Concrete selection beats template-level selection.
        if matched.specificity == earlier.specificity and
            earlier.name != named.name:
          failAt(selection.span,
            "conflicting layout selections for class '" & className & "': '" &
              earlier.name & "' and '" & named.name & "'")
      chosen[className] = (named.name, matched.specificity)

  for index in 0 ..< metadata.types.len:
    let className = metadata.types[index].className
    if className notin chosen:
      continue
    let selectedName = chosen[className].name
    for named in metadata.namedLayouts:
      if named.name == selectedName and named.layout.className == className:
        metadata.types[index] = named.layout
        metadata.activeLayouts.add CompileTimeAppliedLayout(
          className: className, layoutName: selectedName
        )
        break
