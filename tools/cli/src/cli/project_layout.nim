## Defines the default on-disk layout used by the official Eido project tool.
## These paths are CLI defaults, not compiler requirements; external build tools may choose others.

import std/[os, strutils]
import ../../../../compiler/src/project/modules/manifest_parser

const
  BuildDirectoryName* = "build"

## Describes default artifacts for one module-rooted Eido project.
type ProjectLayout* = object
  projectRoot*: string
  buildDirectory*: string
  executablePath*: string
  generatedSourcePath*: string

## Converts a module identity into a portable artifact filename.
## Project identity remains unchanged; this only protects filesystem/backend artifact names.
proc artifactFileName*(name: string): string =
  for character in name:
    if character.isAlphaNumeric or character == '_':
      result.add character
    else:
      result.add '_'
  if result.len == 0:
    result = "eido_app"

## Calculates default project-tool paths without creating directories.
## Example: module `shop` builds to `<root>/build/bin/shop`.
proc projectLayout*(manifestPath: string): ProjectLayout =
  let resolvedManifest = absolutePath(manifestPath)
  let root = parentDir(resolvedManifest)
  let manifest = parseModuleManifest(readFile(resolvedManifest), resolvedManifest)
  if manifest.name in [".", ".."] or '/' in manifest.name or '\\' in manifest.name:
    raise newException(
      ValueError,
      "module name cannot be used as a project artifact name: " & manifest.name
    )

  let generatedArtifactName = artifactFileName(manifest.name)
  let buildRoot = root / BuildDirectoryName

  ProjectLayout(
    projectRoot: root,
    buildDirectory: buildRoot,
    executablePath: buildRoot / "bin" / manifest.name,
    generatedSourcePath:
      buildRoot / "generated" / "nim" /
        (generatedArtifactName & "_generated.nim")
  )

## Creates only the directories owned by the default Eido project build layout.
proc prepareProjectLayout*(layout: ProjectLayout) =
  createDir(layout.buildDirectory)
  createDir(parentDir(layout.executablePath))
  createDir(parentDir(layout.generatedSourcePath))

## Removes artifacts owned by the default Eido project build layout.
proc cleanProjectLayout*(layout: ProjectLayout) =
  if dirExists(layout.buildDirectory):
    removeDir(layout.buildDirectory)
