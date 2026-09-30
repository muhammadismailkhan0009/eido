## Implements the thin Eido Language Server Protocol adapter.
## Compiler/project tooling remains authoritative for parsing, modules, typing, and diagnostics.

import std/[json, os, sets, tables]
import ../../../compiler/src/diagnostics/errors
import ../../../compiler/src/project/model
import ../../../compiler/src/tooling/[compiler_service, formatting_service, hover_service, symbol_service]
import protocol/[diagnostics, jsonrpc, positions, semantic_tokens]
import workspace/[documents, project_session]

type
  LanguageServer* = object
    documents*: DocumentStore
    shutdownRequested*: bool
    publishedPaths: HashSet[string]

## Creates a language server with no open documents.
proc initLanguageServer*(): LanguageServer =
  LanguageServer(
    documents: initDocumentStore(),
    publishedPaths: initHashSet[string]()
  )

## Returns the JSON-RPC id or JSON null for a notification.
proc messageId(message: JsonNode): JsonNode =
  if message.hasKey("id"): message["id"] else: newJNull()

## Builds a window/showMessage notification for project-level failures.
proc showError(message: string): JsonNode =
  rpcNotification("window/showMessage", %*{"type": 1, "message": message})

## Returns the document version from an LSP textDocument object.
proc documentVersion(textDocument: JsonNode): int =
  if textDocument.hasKey("version"): textDocument["version"].getInt else: 0

## Applies the workspace root supplied by initialize.
proc configureWorkspace(server: var LanguageServer, params: JsonNode) =
  var rootPath = ""
  if params.hasKey("workspaceFolders") and
      params["workspaceFolders"].kind == JArray and
      params["workspaceFolders"].len > 0:
    rootPath = fileUriToPath(params["workspaceFolders"][0]["uri"].getStr)
  elif params.hasKey("rootUri") and params["rootUri"].kind == JString:
    rootPath = fileUriToPath(params["rootUri"].getStr)
  server.documents.workspaceRoot = rootPath

## Builds the LSP initialize result for the currently implemented server surface.
proc initializeResult(): JsonNode =
  %*{
    "capabilities": {
      "positionEncoding": "utf-16",
      "textDocumentSync": {
        "openClose": true,
        "change": 1,
        "save": {"includeText": true}
      },
      "hoverProvider": true,
      "documentFormattingProvider": true,
      "definitionProvider": true,
      "semanticTokensProvider": {
        "legend": {
          "tokenTypes": [
            "class",
            "interface",
            "function",
            "method",
            "property",
            "parameter",
            "variable",
            "comment"
          ],
          "tokenModifiers": [
            "declaration",
            "static"
          ]
        },
        "full": true,
        "range": false
      }
    },
    "serverInfo": {"name": "eido-lsp", "version": "0.0.1"}
  }

## Returns whether one loaded project contains a source path.
proc projectContains(project: EidoProject, sourcePath: string): bool =
  let normalized = absolutePath(sourcePath)
  for source in project.sources:
    if absolutePath(source.path) == normalized:
      return true
  false

## Publishes compiler diagnostics for the project containing one source document.
proc refreshDiagnostics*(
  server: var LanguageServer,
  sourceUri: string
): seq[JsonNode] =
  let sourcePath = fileUriToPath(sourceUri)
  if sourcePath.len == 0:
    return

  let manifestPath = server.documents.findProjectManifest(sourcePath)
  if manifestPath.len == 0:
    result.add publishDiagnostics(sourceUri, @[])
    result.add showError("Eido: no module.yaml found for " & sourcePath)
    return

  var project: EidoProject
  try:
    project = server.documents.loadOverlayProject(manifestPath)
  except CompilerError as error:
    result.add publishDiagnostics(sourceUri, @[])
    result.add showError(error.diagnostic.message)
    return
  except CatchableError as error:
    result.add publishDiagnostics(sourceUri, @[])
    result.add showError("Eido project load failed: " & error.msg)
    return

  if not project.projectContains(sourcePath):
    result.add publishDiagnostics(
      sourceUri,
      @[
        %*{
          "range": lspRange(
            server.documents.effectiveSourceText(sourcePath),
            0,
            1
          ),
          "severity": 2,
          "code": "EIDO-LSP001",
          "source": "eido",
          "message": "source file is not listed by its module.yaml sources"
        }
      ]
    )
    return

  let checkResult = checkProject(project)
  for source in project.sources:
    let path = absolutePath(source.path)
    let uri = pathToFileUri(path)
    var sourceDiagnostics: seq[JsonNode]
    if not checkResult.success:
      for diagnostic in checkResult.diagnostics:
        if diagnostic.hasSpan and
            absolutePath(diagnostic.span.sourcePath) == path:
          sourceDiagnostics.add compilerDiagnosticToLsp(
            diagnostic,
            server.documents.effectiveSourceText(path)
          )

    result.add publishDiagnostics(uri, sourceDiagnostics)
    server.publishedPaths.incl path

  if not checkResult.success:
    for diagnostic in checkResult.diagnostics:
      if not diagnostic.hasSpan:
        result.add showError("Eido: " & diagnostic.message)

## Builds a semantic hover response for one document position.
proc hoverResponse(
  server: LanguageServer,
  params: JsonNode
): JsonNode =
  let uri = params["textDocument"]["uri"].getStr
  let path = fileUriToPath(uri)
  if path.len == 0:
    return newJNull()

  let manifestPath = server.documents.findProjectManifest(path)
  if manifestPath.len == 0:
    return newJNull()

  try:
    let project = server.documents.loadOverlayProject(manifestPath)
    let checked = checkProject(project)
    if not checked.success:
      return newJNull()

    let sourceText = server.documents.effectiveSourceText(path)
    let position = params["position"]
    let offset = byteOffsetAt(
      sourceText,
      position["line"].getInt,
      position["character"].getInt
    )
    let hover = hoverInfoAt(checked.program, absolutePath(path), offset)
    if not hover.found:
      return newJNull()

    %*{
      "contents": {
        "language": "eido",
        "value": hover.contents
      },
      "range": lspRange(
        sourceText,
        hover.span.startOffset,
        hover.span.endOffset
      )
    }
  except CatchableError:
    newJNull()

## Loads and checks the project owning one source, then builds compiler semantic symbols.
proc checkedSymbolIndex(
  server: LanguageServer,
  sourcePath: string
): tuple[success: bool, project: EidoProject, index: SymbolIndex] =
  let manifestPath = server.documents.findProjectManifest(sourcePath)
  if manifestPath.len == 0:
    return

  try:
    result.project = server.documents.loadOverlayProject(manifestPath)
    let checked = checkProject(result.project)
    if not checked.success:
      return
    result.index = buildSymbolIndex(checked.program, result.project)
    result.success = true
  except CatchableError:
    discard

## Builds an LSP semantic-token response from the compiler symbol index.
proc semanticTokensResponse(
  server: LanguageServer,
  params: JsonNode
): JsonNode =
  let uri = params["textDocument"]["uri"].getStr
  let path = fileUriToPath(uri)
  if path.len == 0:
    return %*{"data": []}

  let sourceText = server.documents.effectiveSourceText(path)
  let context = server.checkedSymbolIndex(path)
  if context.success:
    return semanticTokensResult(
      context.index,
      path,
      sourceText
    )

  # Lexical comment highlighting does not require a semantically valid project.
  try:
    semanticTokensResult(
      SymbolIndex(),
      path,
      sourceText
    )
  except CatchableError:
    %*{"data": []}

## Builds an LSP location for the compiler-resolved definition at one source position.
proc definitionResponse(
  server: LanguageServer,
  params: JsonNode
): JsonNode =
  let uri = params["textDocument"]["uri"].getStr
  let path = fileUriToPath(uri)
  if path.len == 0:
    return newJNull()

  let context = server.checkedSymbolIndex(path)
  if not context.success:
    return newJNull()

  let sourceText = server.documents.effectiveSourceText(path)
  let position = params["position"]
  let offset = byteOffsetAt(
    sourceText,
    position["line"].getInt,
    position["character"].getInt
  )
  let matched = context.index.symbolAt(path, offset)
  if not matched.found:
    return newJNull()

  let definition = matched.symbol.declarationSpan
  if definition.sourcePath.len == 0:
    return newJNull()

  let targetPath = absolutePath(definition.sourcePath)
  let targetText = server.documents.effectiveSourceText(targetPath)
  if targetText.len == 0:
    return newJNull()

  %*{
    "uri": pathToFileUri(targetPath),
    "range": lspRange(
      targetText,
      definition.startOffset,
      definition.endOffset
    )
  }

## Builds a full-document formatting edit from the current editor overlay.
proc formattingResponse(
  server: LanguageServer,
  params: JsonNode
): JsonNode =
  let uri = params["textDocument"]["uri"].getStr
  let path = fileUriToPath(uri)
  if path.len == 0:
    return newJArray()

  let sourceText = server.documents.effectiveSourceText(path)
  if sourceText.len == 0:
    return newJArray()

  try:
    let formatted = formatSource(sourceText)
    if formatted == sourceText:
      return newJArray()

    %*[
      {
        "range": {
          "start": {"line": 0, "character": 0},
          "end": lspPositionAt(sourceText, sourceText.len)
        },
        "newText": formatted
      }
    ]
  except CatchableError:
    newJArray()

## Handles one JSON-RPC/LSP message and returns zero or more outbound messages.
proc handleMessage*(
  server: var LanguageServer,
  message: JsonNode
): seq[JsonNode] =
  if message.isNil or not message.hasKey("method"):
    return

  let methodName = message["method"].getStr
  let params =
    if message.hasKey("params"): message["params"] else: newJObject()
  let id = message.messageId

  case methodName
  of "initialize":
    server.configureWorkspace(params)
    result.add rpcResponse(id, initializeResult())
  of "initialized", "$/cancelRequest":
    discard
  of "shutdown":
    server.shutdownRequested = true
    result.add rpcResponse(id, newJNull())
  of "exit":
    discard
  of "textDocument/didOpen":
    let document = params["textDocument"]
    server.documents.put(
      document["uri"].getStr,
      document["text"].getStr,
      document.documentVersion
    )
    result.add server.refreshDiagnostics(document["uri"].getStr)
  of "textDocument/didChange":
    let document = params["textDocument"]
    if params.hasKey("contentChanges") and params["contentChanges"].len > 0:
      let latest = params["contentChanges"][^1]
      server.documents.put(
        document["uri"].getStr,
        latest["text"].getStr,
        document.documentVersion
      )
      result.add server.refreshDiagnostics(document["uri"].getStr)
  of "textDocument/didSave":
    let document = params["textDocument"]
    let uri = document["uri"].getStr
    let path = fileUriToPath(uri)
    if params.hasKey("text") and params["text"].kind == JString:
      server.documents.put(
        uri,
        params["text"].getStr,
        if server.documents.hasOpenPath(path):
          server.documents.byPath[absolutePath(path)].version
        else:
          0
      )
    result.add server.refreshDiagnostics(uri)
  of "textDocument/didClose":
    let uri = params["textDocument"]["uri"].getStr
    server.documents.remove(uri)
    result.add server.refreshDiagnostics(uri)
  of "textDocument/hover":
    result.add rpcResponse(id, server.hoverResponse(params))
  of "textDocument/semanticTokens/full":
    result.add rpcResponse(id, server.semanticTokensResponse(params))
  of "textDocument/definition":
    result.add rpcResponse(id, server.definitionResponse(params))
  of "textDocument/formatting":
    result.add rpcResponse(id, server.formattingResponse(params))
  else:
    if message.hasKey("id"):
      result.add rpcError(id, -32601, "method not implemented: " & methodName)

## Runs the language server over Content-Length framed input/output streams.
proc runLanguageServer*(input: File = stdin, output: File = stdout) =
  var server = initLanguageServer()
  while true:
    let message =
      try:
        readRpcMessage(input)
      except CatchableError as error:
        writeRpcMessage(
          output,
          rpcError(newJNull(), -32700, "parse error: " & error.msg)
        )
        continue

    if message.isNil:
      break

    let methodName =
      if message.hasKey("method"): message["method"].getStr else: ""

    for outbound in server.handleMessage(message):
      writeRpcMessage(output, outbound)

    if methodName == "exit":
      break
