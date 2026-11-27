## Compile-time SDK embedding uses the same manifest source discovery as users.
import std/[os, strutils, macros, sets]
import ../project/modules/[manifest_parser, model, source_directories]

type
  EmbeddedSource* = tuple[entry, path, text: string, policy: bool]
  EmbeddedModule* = tuple[path, text: string, sources: seq[EmbeddedSource]]

## Embeds exactly the source set discovered by the ordinary filesystem loader.
## The installed compiler never consults the checkout at runtime.
macro embedStdlibTree(): untyped =
  let root = currentSourcePath().parentDir / "../../../stdlib"
  let catalog = newNimNode(nnkBracket)
  var manifests = initHashSet[string]()

  ## Recursively embeds each declared manifest and its expanded source set.
  proc visit(directory: string) =
    let manifestFile = directory / "module.yaml"
    if manifestFile in manifests:
      raise newException(ValueError, "duplicate embedded module manifest: " & manifestFile)
    manifests.incl manifestFile
    let manifest = parseModuleManifest(readFile(manifestFile), manifestFile)
    let sourceNodes = newNimNode(nnkBracket)

    ## Embeds one payload and retains its exact manifest entry/role.
    proc addSource(path, entry: string, policy: bool) =
      let virtualPath = "eido://stdlib/" & relativePath(path, root).replace('\\', '/')
      sourceNodes.add newTree(nnkTupleConstr, newLit(entry), newLit(virtualPath),
        newCall("staticRead", newLit(path)), newLit(policy))

    for path in discoverModuleSources(directory, manifestFile, manifest):
      addSource(path, relativePath(path, directory).replace('\\', '/'), false)
    for entry in manifest.policySources:
      let path = normalizedPath(absolutePath(directory / entry, directory))
      if not fileExists(path) or path.splitFile.ext != ".eido":
        raise newException(ValueError, "invalid embedded policy source: " & path)
      addSource(path, entry, true)

    let virtualManifest = "<eido-sdk>/stdlib/" & relativePath(manifestFile, root).replace('\\', '/')
    catalog.add newTree(nnkTupleConstr, newLit(virtualManifest),
      newCall("staticRead", newLit(manifestFile)),
      newTree(nnkPrefix, ident"@", sourceNodes))
    for child in manifest.children:
      visit(normalizedPath(absolutePath(directory / child.path, directory)))

  visit(root)
  result = newTree(nnkPrefix, ident"@", catalog)

const EmbeddedStdlib: seq[EmbeddedModule] = embedStdlibTree()

## Returns the manifest and ordered payloads from the installed SDK catalog.
proc embeddedModule*(manifestPath: string): EmbeddedModule =
  for item in EmbeddedStdlib:
    if item.path == manifestPath: return item
  raise newException(ValueError, "embedded stdlib references unknown manifest '" & manifestPath & "'")
