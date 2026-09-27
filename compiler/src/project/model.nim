## Defines the compiler-level Eido project and its compilation target.
## Example: an executable project may contain main.eido, account.eido, and service.eido.

import ../source/source_unit

type
  ProjectTarget* = enum
    ptExecutable,
    ptLibrary

  EidoProject* = object
    target*: ProjectTarget
    sources*: seq[SourceUnit]

## Creates an Eido project from an explicit target and ordered source set.
## Example: `initProject(ptLibrary, sources)` creates reusable code with no main requirement.
proc initProject*(target: ProjectTarget, sources: seq[SourceUnit]): EidoProject =
  EidoProject(target: target, sources: sources)
