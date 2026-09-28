## Defines the compiler-level Eido project and its compilation target.
## Example: an executable project may contain main.eido, account.eido, and service.eido.

import ../source/source_unit
import modules/model as moduleModel

type
  ProjectTarget* = enum
    ptExecutable,
    ptLibrary

  EidoProject* = object
    target*: ProjectTarget
    sources*: seq[SourceUnit]
    modules*: seq[moduleModel.ModuleSpec]
    rootModule*: string

## Creates an Eido project from an explicit target and ordered source set.
## Example: `initProject(ptLibrary, sources)` creates reusable code with no main requirement.
proc initProject*(target: ProjectTarget, sources: seq[SourceUnit]): EidoProject =
  EidoProject(target: target, sources: sources)

## Creates a module-aware project after module.yaml loading and architecture validation.
proc initModuleProject*(
  target: ProjectTarget,
  sources: seq[SourceUnit],
  modules: seq[moduleModel.ModuleSpec],
  rootModule: string
): EidoProject =
  EidoProject(
    target: target,
    sources: sources,
    modules: modules,
    rootModule: rootModule
  )
