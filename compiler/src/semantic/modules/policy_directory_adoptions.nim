## Discovers adoption names in the separate build-machine policy source role.
## The same manifest controls both roles, but their declaration universes do not mix.
import std/sets
import ../../project/modules/[model, source_directories]
import ../../source/source_unit
import ../../frontend/lexer/scanner
import ../../frontend/parser/program_parser

## Lists declaration names owned by explicitly registered policy files.
proc policyDirectoryAdoptionNames*(spec: ModuleSpec): HashSet[string] =
  result = initHashSet[string]()
  for index, item in spec.policySources:
    let parsed = parseProgram(lexAll(initSourceUnit(index, item.path, item.text, spec.canonicalName)))
    for decl in parsed.classes:
      result.incl directoryAdoptionName(spec, item.path, decl.name)
    for decl in parsed.interfaces:
      result.incl directoryAdoptionName(spec, item.path, decl.name)
    for decl in parsed.functions:
      result.incl directoryAdoptionName(spec, item.path, decl.name)
    for decl in parsed.layouts:
      result.incl directoryAdoptionName(spec, item.path, decl.name)
