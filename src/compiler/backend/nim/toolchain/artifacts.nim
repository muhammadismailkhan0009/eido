## Owns generated Nim artifact paths and file writing. Example: output `bin/app` uses `bin/app_generated.nim` during development.

## Calculates the retained generated-Nim filename. Example: output `bin/app` maps to `bin/app_generated.nim`.
proc generatedNimPath*(outputPath: string): string =
  outputPath & "_generated.nim"

## Writes generated Nim source to its development artifact path. Example: emitted text for `bin/app` is stored in `bin/app_generated.nim`.
proc writeGeneratedNim*(outputPath, source: string): string =
  result = generatedNimPath(outputPath)
  writeFile(result, source)
