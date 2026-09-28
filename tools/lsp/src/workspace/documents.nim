## Owns open editor document overlays and project-manifest discovery for the LSP adapter.

import std/[os, strutils, tables, uri]

type
  OpenDocument* = object
    uri*: string
    path*: string
    text*: string
    version*: int

  DocumentStore* = object
    byPath*: Table[string, OpenDocument]
    workspaceRoot*: string

## Creates an empty document store scoped to an optional workspace root.
proc initDocumentStore*(workspaceRoot: string = ""): DocumentStore =
  DocumentStore(
    byPath: initTable[string, OpenDocument](),
    workspaceRoot:
      if workspaceRoot.len == 0: ""
      else: absolutePath(workspaceRoot)
  )

## Converts one file URI to an absolute native path.
proc fileUriToPath*(uriText: string): string =
  let parsed = parseUri(uriText)
  if parsed.scheme != "file":
    return ""
  absolutePath(decodeUrl(parsed.path))

## Converts one native path to a file URI suitable for LSP messages.
proc pathToFileUri*(path: string): string =
  let normalized = absolutePath(path).replace('\\', '/')
  "file://" & encodeUrl(normalized, usePlus = false).replace("%2F", "/")

## Inserts or replaces one full editor document snapshot.
proc put*(
  store: var DocumentStore,
  uri, text: string,
  version: int
) =
  let path = fileUriToPath(uri)
  if path.len == 0:
    return
  store.byPath[path] = OpenDocument(
    uri: uri,
    path: path,
    text: text,
    version: version
  )

## Removes one closed editor overlay.
proc remove*(store: var DocumentStore, uri: string) =
  let path = fileUriToPath(uri)
  if path in store.byPath:
    store.byPath.del(path)

## Returns the current text for an open path, or empty if the document is not open.
proc openText*(store: DocumentStore, path: string): string =
  let normalized = absolutePath(path)
  if normalized in store.byPath:
    store.byPath[normalized].text
  else:
    ""

## Reports whether a source path currently has an editor overlay.
proc hasOpenPath*(store: DocumentStore, path: string): bool =
  absolutePath(path) in store.byPath

## Finds the outermost module.yaml between a source file and the workspace/filesystem root.
proc findProjectManifest*(store: DocumentStore, sourcePath: string): string =
  let absoluteSource = absolutePath(sourcePath)
  var directory =
    if dirExists(absoluteSource): absoluteSource
    else: parentDir(absoluteSource)

  let stopDirectory =
    if store.workspaceRoot.len > 0 and absoluteSource.startsWith(store.workspaceRoot):
      store.workspaceRoot
    else:
      ""

  var found = ""
  while directory.len > 0:
    let candidate = directory / "module.yaml"
    if fileExists(candidate):
      found = candidate

    if stopDirectory.len > 0 and directory == stopDirectory:
      break

    let parent = parentDir(directory)
    if parent == directory:
      break
    directory = parent

  found
