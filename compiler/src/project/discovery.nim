## Locates the architecture root for project-oriented Eido tooling.
## Discovery is intentionally separate from the CLI so editors and future build tools may reuse it.

import std/os

## Finds the outermost ancestor module.yaml starting from a directory.
## Nested module manifests are skipped in favor of the owning architecture root.
proc findProjectManifest*(startDirectory: string): string =
  var current = absolutePath(startDirectory)
  var discovered = ""

  if fileExists(current):
    current = parentDir(current)

  while true:
    let candidate = current / "module.yaml"
    if fileExists(candidate):
      discovered = absolutePath(candidate)

    let parent = parentDir(current)
    if parent.len == 0 or parent == current:
      break
    current = parent

  if discovered.len == 0:
    raise newException(
      ValueError,
      "no Eido project found from '" & absolutePath(startDirectory) &
        "'; expected module.yaml in this directory or an ancestor"
    )

  discovered

## Resolves an explicit project manifest or discovers one from the supplied directory.
## Explicit manifests remain available for external build systems and scripted orchestration.
proc resolveProjectManifest*(
  explicitManifest,
  startDirectory: string
): string =
  if explicitManifest.len == 0:
    return findProjectManifest(startDirectory)

  let resolved = absolutePath(explicitManifest)
  if resolved.extractFilename != "module.yaml":
    raise newException(ValueError, "Eido project manifest must be named module.yaml")
  if not fileExists(resolved):
    raise newException(ValueError, "Eido project manifest does not exist: " & resolved)
  resolved

## Resolves an explicit manifest or discovers from the process's current directory at call time.
## The overload avoids freezing a changing working directory into a default argument.
proc resolveProjectManifest*(explicitManifest: string): string =
  resolveProjectManifest(explicitManifest, getCurrentDir())
