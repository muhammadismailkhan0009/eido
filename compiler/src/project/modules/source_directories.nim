## Source discovery and internal directory boundaries shared by module loaders.
import std/[os, strutils, algorithm, sets]
import ../../diagnostics/errors
import model

## Returns a normalized source path in the same namespace as the manifest.
proc moduleSourceRelative*(spec: ModuleSpec, sourcePath: string): string =
  var path = sourcePath
  let base = spec.directory
  if path.startsWith("eido://stdlib/"):
    path = "<eido-sdk>/stdlib/" & path["eido://stdlib/".len .. ^1]
  if base.len == 0: return path.extractFilename
  # Virtual SDK/phase paths are relative to the same virtual root.
  relativePath(normalizedPath(path), normalizedPath(base)).replace('\\', '/')

## Immediate directory subtree; files directly owned at the root share one group.
## Explicitly registered files outside the module directory belong to a distinct
## external directory group, never to an in-tree directory of the same name.
proc sourceDirectoryGroup*(spec: ModuleSpec, sourcePath: string): string =
  let parts = moduleSourceRelative(spec, sourcePath).split('/')
  var index = 0
  while index < parts.len and parts[index] == "..": inc index
  if index == 0:
    if parts.len > 1: return parts[0]
    return ""
  if index < parts.high: return parts[0 .. index].join("/")
  parts[0 ..< index].join("/")

## Manifest spelling for one internal declaration; root declarations use a bare name.
proc directoryAdoptionName*(spec: ModuleSpec, sourcePath, localName: string): string =
  let group = sourceDirectoryGroup(spec, sourcePath)
  if group.len == 0: localName else: group & "." & localName

## True when a directory is contained in another by normalized path components.
proc pathWithin*(path, base: string): bool =
  let rel = relativePath(path, base)
  rel == "." or (not rel.isAbsolute and rel != ".." and
    not rel.startsWith(".." & $DirSep))

## A declared module child may physically enclose the owning manifest (for
## example a package's tests declaring the package with path: ..). Its
## ancestor directory must not exclude the owner's own manifest subtree.
proc belongsToChildRoot(path, directory, child: string): bool =
  pathWithin(path, child) and not (
    child != directory and pathWithin(directory, child) and
    pathWithin(path, directory)
  )

## Detects symbolic links in both runtime and compiler VM discovery.
proc sourceIsSymlink(path: string): bool =
  when nimvm:
    let parent = parentDir(path)
    if dirExists(parent):
      for kind, candidate in walkDir(parent):
        if candidate == path: return kind in {pcLinkToFile, pcLinkToDir}
  else:
    return symlinkExists(path)

## Resolve ordinary module source entries in deterministic order. Directory
## entries never cross another manifest or declared child root, and do not follow
## symlinks. Explicit files retain the existing registration semantics.
proc discoverModuleSources*(directory, manifestPath: string,
    manifest: ModuleManifest): seq[string] =
  var excluded = initHashSet[string]()
  for child in manifest.children:
    excluded.incl normalizedPath(absolutePath(directory / child.path, directory))
  var policyPaths = initHashSet[string]()
  for entry in manifest.policySources:
    policyPaths.incl normalizedPath(absolutePath(directory / entry, directory))
  var seen = initHashSet[string]()
  var discovered: seq[string]

  ## Visits a registered directory without crossing a separate module.
  proc visit(dir: string, output: var seq[string]) =
    if dir in excluded or (dir != directory and fileExists(dir / "module.yaml")):
      return
    var entries: seq[tuple[kind: PathComponent, path: string]]
    for item in walkDir(dir): entries.add item
    entries.sort(proc(a,b: tuple[kind: PathComponent, path: string]): int = cmp(a.path,b.path))
    for item in entries:
      case item.kind
      of pcDir: visit(item.path, output)
      of pcFile:
        if item.path.splitFile.ext == ".eido" and item.path notin policyPaths:
          output.add item.path
      else: discard

  for entry in manifest.sources:
    let path = normalizedPath(absolutePath(directory / entry, directory))
    var selected: seq[string]
    if dirExists(path):
      if sourceIsSymlink(path) or not pathWithin(path, directory):
        failAt(manifestPath, 1, 1, "source directory must be inside its module: " & entry)
      for child in excluded:
        if belongsToChildRoot(path, directory, child):
          failAt(manifestPath, 1, 1, "source directory belongs to a child module: " & entry)
      var ancestor = path
      while ancestor != directory:
        if fileExists(ancestor / "module.yaml") or sourceIsSymlink(ancestor):
          failAt(manifestPath, 1, 1, "source directory crosses a module or symlink boundary: " & entry)
        ancestor = parentDir(ancestor)
      visit(path, selected)
      selected.sort()
    else:
      if path.splitFile.ext != ".eido" or not fileExists(path):
        failAt(manifestPath, 1, 1, "module source must be an existing .eido file or directory: " & entry)
      for child in excluded:
        if belongsToChildRoot(path, directory, child):
          failAt(manifestPath, 1, 1, "source file belongs to a child module: " & entry)
      var ancestor = parentDir(path)
      # External explicitly registered support files remain legal, but an
      # independently manifest-owned tree cannot be imported as loose files.
      while ancestor.len > 0 and ancestor != directory and not pathWithin(directory, ancestor):
        if fileExists(ancestor / "module.yaml") or sourceIsSymlink(ancestor):
          failAt(manifestPath, 1, 1, "source file crosses a module or symlink boundary: " & entry)
        let next = parentDir(ancestor)
        if next == ancestor: break
        ancestor = next
      if sourceIsSymlink(path):
        failAt(manifestPath, 1, 1, "module source must not be a symlink: " & entry)
      selected.add path
    for sourcePath in selected:
      if sourcePath in seen or sourcePath in policyPaths:
        failAt(manifestPath, 1, 1, "duplicate module source or policy source: " & sourcePath)
      seen.incl sourcePath
      discovered.add sourcePath
  discovered
