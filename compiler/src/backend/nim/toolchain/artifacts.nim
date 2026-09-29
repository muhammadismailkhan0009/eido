## Owns generated Nim artifact paths and file writing.
## Backend source names are sanitized independently from user-facing executable names.

import std/[os, strutils]

## Converts one output filename into a Nim-safe generated module stem.
## Example: executable `enterprise-app` uses generated module stem `enterprise_app`.
proc generatedModuleStem(name: string): string =
  for character in name:
    if character.isAlphaNumeric or character == '_':
      result.add character
    else:
      result.add '_'

  if result.len == 0:
    result = "eido_generated"
  elif result[0].isDigit:
    result = "eido_" & result

## Calculates the retained generated-Nim filename beside an explicit output.
## User-facing output names may contain characters that cannot appear in Nim module filenames.
proc generatedNimPath*(outputPath: string): string =
  let directory = parentDir(outputPath)
  let stem = generatedModuleStem(outputPath.extractFilename)
  let filename = stem & "_generated.nim"
  if directory.len == 0: filename else: directory / filename

## Writes generated Nim source to an explicit development artifact path.
## Parent directories are created so build tools may choose isolated work directories.
proc writeGeneratedNimAt*(path, source: string): string =
  let directory = parentDir(path)
  if directory.len > 0:
    createDir(directory)
  writeFile(path, source)
  path

## Writes generated Nim source beside an explicit output using a sanitized internal name.
proc writeGeneratedNim*(outputPath, source: string): string =
  writeGeneratedNimAt(generatedNimPath(outputPath), source)
