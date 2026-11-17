## Validates Eido class layouts before any backend receives raw offsets.
## Named alternative layouts are checked even though they are not yet selected.

import ../hir/program as hirProgram
import ../hir/declarations as hirDeclarations
import ../types/model
import ../types/storage
import ../source/span
import target_storage_layout
import model

## Counts ordinary class declarations that receive generic object-layout metadata.
proc expectedClassLayouts(program: hirProgram.HirProgram): int =
  for classDecl in program.classes:
    if not isConcreteStorageTypeName(classDecl.sourceName) and
        not classDecl.span.isHiddenRuntime:
      inc result

## Validates the exact physical mapping, not only record counts and sizes.
## This is the trust boundary before generated direct pointer operations.
proc validateTypeLayout(
  program: hirProgram.HirProgram,
  layout: CompileTimeTypeMetadata,
  label: string
) =
  var found = false
  var sourceClass: hirDeclarations.HirClass
  for classDecl in program.classes:
    if classDecl.sourceName == layout.className:
      sourceClass = classDecl
      found = true
      break
  if not found:
    raise newException(ValueError, label & ": unknown class '" & layout.className & "'")
  if layout.size < 0 or layout.alignment <= 0 or
      (layout.alignment and (layout.alignment - 1)) != 0 or
      layout.size mod layout.alignment != 0:
    raise newException(ValueError, label & ": invalid size or alignment")
  if layout.fields.len != sourceClass.fields.len:
    raise newException(ValueError,
      label & ": must place every instance field exactly once")

  for field in layout.fields:
    var matched = false
    var fieldType: EidoType
    for declared in sourceClass.fields:
      if declared.sourceName == field.fieldName:
        matched = true
        fieldType = declared.typ
        break
    if not matched:
      raise newException(ValueError,
        label & ": unknown field '" & field.fieldName & "'")

    let requirements = storageLayoutOf(fieldType)
    if field.offset < 0 or
        field.offset > high(int64) - requirements.size or
        field.offset mod requirements.alignment != 0 or
        field.offset + requirements.size > layout.size or
        requirements.alignment > layout.alignment:
      raise newException(ValueError,
        label & ": invalid placement for '" & field.fieldName & "'")

    for other in layout.fields:
      if other.fieldName == field.fieldName:
        continue
      var otherFound = false
      var otherType: EidoType
      for declared in sourceClass.fields:
        if declared.sourceName == other.fieldName:
          otherFound = true
          otherType = declared.typ
          break
      if not otherFound:
        raise newException(ValueError, label & ": unknown field '" & other.fieldName & "'")
      let otherSize = storageLayoutOf(otherType).size
      if requirements.size > 0 and otherSize > 0 and
          other.offset >= 0 and other.offset <= high(int64) - otherSize and
          field.offset < other.offset + otherSize and
          other.offset < field.offset + requirements.size:
        raise newException(ValueError,
          label & ": overlapping fields '" & field.fieldName & "' and '" &
            other.fieldName & "'")

  for declared in sourceClass.fields:
    var occurrences = 0
    for field in layout.fields:
      if field.fieldName == declared.sourceName:
        inc occurrences
    if occurrences != 1:
      raise newException(ValueError,
        label & ": field '" & declared.sourceName & "' must appear exactly once")

## Verifies default layouts and all unselected named alternatives.
proc validateMetadata*(
  program: hirProgram.HirProgram,
  metadata: CompileTimeMemoryMetadata
) =
  if metadata.types.len != expectedClassLayouts(program):
    raise newException(ValueError,
      "memory metadata did not return one layout per ordinary class")

  for typeMetadata in metadata.types:
    validateTypeLayout(program, typeMetadata, "default layout")

  if metadata.namedLayouts.len != program.layouts.len:
    raise newException(ValueError,
      "memory metadata did not return every named layout")

  for named in metadata.namedLayouts:
    validateTypeLayout(program, named.layout, "layout '" & named.name & "'")
