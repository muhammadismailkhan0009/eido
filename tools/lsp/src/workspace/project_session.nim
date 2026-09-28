## Builds compiler projects from disk plus unsaved editor overlays.
## No parsing, name resolution, or typing is reimplemented here.

import std/os
import ../../../../compiler/src/project/model
import ../../../../compiler/src/project/modules/loader
import ../../../../compiler/src/tooling/compiler_service
import documents

## Loads one module project and replaces disk source text with currently open editor snapshots.
proc loadOverlayProject*(
  store: DocumentStore,
  manifestPath: string,
  target: ProjectTarget = ptLibrary
): EidoProject =
  result = loadModuleProject(manifestPath, target)

  for source in mitems(result.sources):
    let normalized = absolutePath(source.path)
    if store.hasOpenPath(normalized):
      source.text = store.openText(normalized)

## Checks one manifest project against the current editor snapshots.
proc checkOverlayProject*(
  store: DocumentStore,
  manifestPath: string
): ProjectCheckResult =
  checkProject(store.loadOverlayProject(manifestPath))

## Returns source text from the editor overlay when open, otherwise from disk.
proc effectiveSourceText*(store: DocumentStore, path: string): string =
  if store.hasOpenPath(path):
    return store.openText(path)
  if fileExists(path):
    return readFile(path)
  ""
