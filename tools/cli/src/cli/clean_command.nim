## Cleans artifacts created by the official default Eido project layout.
## External build systems remain responsible for their own artifact directories.

import project_layout

## Removes the default build tree for one resolved project manifest.
proc cleanModuleProject*(manifestPath: string) =
  cleanProjectLayout(projectLayout(manifestPath))
