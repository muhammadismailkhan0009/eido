## Preserves the single-source compiler API as a convenience over the project compiler.
## Example: `compileToNim(source)` creates one anonymous executable source unit and runs the normal project pipeline.

import ../project/model
import ../source/source_unit
import project_compiler

## Runs one anonymous Eido source string through the executable project pipeline.
## Example: `function main() returns Int { return 5; }` still compiles without callers constructing a Project explicitly.
proc compileToNim*(source: string): string =
  compileProjectToNim(
    initProject(ptExecutable, @[initSourceUnit(0, "", source)])
  )
