## Runs package/project-owned Eido tests from the conventional tests/module.yaml root.

import std/os
import ../../../../compiler/src/pipeline/options
import ../../../../compiler/src/project/discovery
import project_layout
import run_command

## Resolves the production project manifest represented by a test command target.
proc resolveTestTargetManifest*(target: string): string =
  if target.len == 0:
    return resolveProjectManifest("")

  let resolved = absolutePath(target)
  if dirExists(resolved):
    let manifest = resolved / "module.yaml"
    if not fileExists(manifest):
      raise newException(
        ValueError,
        "Eido test target does not contain module.yaml: " & resolved
      )
    return manifest

  if resolved.extractFilename != "module.yaml":
    raise newException(
      ValueError,
      "Eido test target must be a project directory or module.yaml: " & target
    )
  if not fileExists(resolved):
    raise newException(ValueError, "Eido test target does not exist: " & resolved)
  resolved

## Finds the conventional package/project-owned test module.
proc resolveTestManifest*(target: string): string =
  let projectManifest = resolveTestTargetManifest(target)
  let testManifest = parentDir(projectManifest) / "tests" / "module.yaml"
  if not fileExists(testManifest):
    raise newException(
      ValueError,
      "no Eido tests found for '" & parentDir(projectManifest) &
        "'; expected tests/module.yaml"
    )
  testManifest

## Builds and executes one package/project-owned test module.
proc runProjectTests*(
  target: string,
  memoryPolicy: MemoryPolicySelection = DefaultMemoryPolicy
): int =
  let manifest = resolveTestManifest(target)
  runModuleProject(manifest, @[], projectLayout(manifest), memoryPolicy)
