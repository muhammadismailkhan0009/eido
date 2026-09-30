import std/[json, os, unittest]
import server
import protocol/[jsonrpc, positions]
import workspace/documents

## Creates an isolated module project for LSP integration tests.
proc freshLspProject(name: string): string =
  result = getTempDir() / ("eido_lsp_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

## Returns the publishDiagnostics message for one URI from an outbound batch.
proc diagnosticsFor(messages: seq[JsonNode], uri: string): JsonNode =
  for message in messages:
    if message.hasKey("method") and
        message["method"].getStr == "textDocument/publishDiagnostics" and
        message["params"]["uri"].getStr == uri:
      return message
  nil

type
  DecodedSemanticToken = tuple[
    line, character, length, tokenType, modifiers: int
  ]

## Expands LSP delta-encoded semantic tokens for assertions.
proc decodeSemanticTokens(data: JsonNode): seq[DecodedSemanticToken] =
  var line = 0
  var character = 0
  var index = 0

  while index + 4 < data.len:
    let deltaLine = data[index].getInt
    let deltaStart = data[index + 1].getInt
    if deltaLine == 0:
      character += deltaStart
    else:
      line += deltaLine
      character = deltaStart

    result.add (
      line: line,
      character: character,
      length: data[index + 2].getInt,
      tokenType: data[index + 3].getInt,
      modifiers: data[index + 4].getInt
    )
    index += 5

suite "Eido LSP integration":
  test "initialize advertises full sync diagnostics and hover":
    var server = initLanguageServer()
    let root = freshLspProject("initialize")
    defer: removeDir(root)

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {
        "rootUri": pathToFileUri(root)
      }
    })

    check messages.len == 1
    check messages[0]["result"]["capabilities"]["hoverProvider"].getBool
    check messages[0]["result"]["capabilities"]["documentFormattingProvider"].getBool
    check messages[0]["result"]["capabilities"]["definitionProvider"].getBool
    check messages[0]["result"]["capabilities"]["semanticTokensProvider"]["full"].getBool
    check messages[0]["result"]["capabilities"]["semanticTokensProvider"]["legend"]["tokenTypes"][7].getStr == "comment"
    check messages[0]["result"]["capabilities"]["textDocumentSync"]["change"].getInt == 1

  test "didOpen checks unsaved editor text through the real compiler":
    let root = freshLspProject("diagnostics")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let diskSource = "function main() {}"
    let path = root / "Main.eido"
    writeFile(path, diskSource)
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": "function main() { broken(); }"
        }
      }
    })

    let published = diagnosticsFor(messages, uri)
    check not published.isNil
    check published["params"]["diagnostics"].len == 1
    check published["params"]["diagnostics"][0]["code"].getStr == "EIDO1000"

  test "didChange clears diagnostics when unsaved source becomes valid":
    let root = freshLspProject("change")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let path = root / "Main.eido"
    writeFile(path, "function main() {}")
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": "function main() { broken(); }"
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didChange",
      "params": {
        "textDocument": {"uri": uri, "version": 2},
        "contentChanges": [
          {"text": "function main() {}"}
        ]
      }
    })

    let published = diagnosticsFor(messages, uri)
    check not published.isNil
    check published["params"]["diagnostics"].len == 0

  test "hover returns compiler-derived local type":
    let root = freshLspProject("hover")
    defer: removeDir(root)

    let source = """function main() returns Int {
  var value = 41;
  return value + 1;
}
"""
    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let path = root / "Main.eido"
    writeFile(path, source)
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": source
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 2,
      "method": "textDocument/hover",
      "params": {
        "textDocument": {"uri": uri},
        "position": {"line": 2, "character": 9}
      }
    })

    check messages.len == 1
    check messages[0]["result"]["contents"]["value"].getStr == "value: Int"



  test "semantic tokens expose compiler symbol kinds":
    let root = freshLspProject("semantic_tokens")
    defer: removeDir(root)

    let source = """
class Counter {
    Int value;

    function read(Int bonus) returns Int {
        var total = self.value + bonus;
        return total;
    }
}

function main() returns Int {
    var counter = Counter { value = 41; };
    return counter.read(1);
}
"""
    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let path = root / "Main.eido"
    writeFile(path, source)
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": source
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 3,
      "method": "textDocument/semanticTokens/full",
      "params": {
        "textDocument": {"uri": uri}
      }
    })

    check messages.len == 1
    let data = messages[0]["result"]["data"]
    check data.len >= 5
    check data.len mod 5 == 0

    var tokenTypes: seq[int]
    var index = 3
    while index < data.len:
      tokenTypes.add data[index].getInt
      index += 5

    check 0 in tokenTypes # class
    check 3 in tokenTypes # method
    check 4 in tokenTypes # property
    check 5 in tokenTypes # parameter
    check 6 in tokenTypes # variable

  test "semantic tokens expose line comments without matching string content":
    let root = freshLspProject("comment_tokens")
    defer: removeDir(root)

    let source = """// it's a heading
function main() returns Int {
    var value = 8; // value's trailing note
    var text = "https://eido.dev//docs";
    return value / 2;
}
"""
    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let path = root / "Main.eido"
    writeFile(path, source)
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": source
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 4,
      "method": "textDocument/semanticTokens/full",
      "params": {
        "textDocument": {"uri": uri}
      }
    })

    check messages.len == 1
    var comments: seq[string]
    for token in decodeSemanticTokens(messages[0]["result"]["data"]):
      if token.tokenType != 7:
        continue
      let startOffset = byteOffsetAt(source, token.line, token.character)
      let endOffset = byteOffsetAt(
        source,
        token.line,
        token.character + token.length
      )
      comments.add source[startOffset ..< endOffset]

    check comments == @[
      "// it's a heading",
      "// value's trailing note"
    ]

  test "comment semantic tokens remain available when semantic checking fails":
    let root = freshLspProject("comment_tokens_error")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let source = """// still a comment
function main() {
    broken();
}
"""
    let path = root / "Main.eido"
    writeFile(path, source)
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": source
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 5,
      "method": "textDocument/semanticTokens/full",
      "params": {
        "textDocument": {"uri": uri}
      }
    })

    var comments: seq[string]
    for token in decodeSemanticTokens(messages[0]["result"]["data"]):
      if token.tokenType == 7:
        let startOffset = byteOffsetAt(source, token.line, token.character)
        let endOffset = byteOffsetAt(
          source,
          token.line,
          token.character + token.length
        )
        comments.add source[startOffset ..< endOffset]

    check comments == @["// still a comment"]

  test "definition navigates across module files":
    let root = freshLspProject("definition")
    defer: removeDir(root)
    createDir(root / "api")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        api: { path: api }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    let factoryPath = root / "api" / "Factory.eido"
    writeFile(factoryPath, """
class Factory {
    function value() returns Int {
        return 42;
    }
}
""")

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - api
      exports: []
      provides: {}
      adopts: []
    """)
    let mainPath = root / "app" / "Main.eido"
    let mainSource = """
function main() returns Int {
    return Factory.value();
}
"""
    writeFile(mainPath, mainSource)
    let uri = pathToFileUri(mainPath)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": mainSource
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 4,
      "method": "textDocument/definition",
      "params": {
        "textDocument": {"uri": uri},
        "position": {"line": 1, "character": 20}
      }
    })

    check messages.len == 1
    check messages[0]["result"].kind == JObject
    check messages[0]["result"]["uri"].getStr ==
      pathToFileUri(factoryPath)
    check messages[0]["result"]["range"]["start"]["line"].getInt == 1

  test "formatting returns a full document edit":
    let root = freshLspProject("formatting")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    let path = root / "Main.eido"
    writeFile(path, "function main(){}")
    let uri = pathToFileUri(path)

    var server = initLanguageServer()
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 1,
      "method": "initialize",
      "params": {"rootUri": pathToFileUri(root)}
    })
    discard server.handleMessage(%*{
      "jsonrpc": "2.0",
      "method": "textDocument/didOpen",
      "params": {
        "textDocument": {
          "uri": uri,
          "languageId": "eido",
          "version": 1,
          "text": "function main(){}"
        }
      }
    })

    let messages = server.handleMessage(%*{
      "jsonrpc": "2.0",
      "id": 3,
      "method": "textDocument/formatting",
      "params": {
        "textDocument": {"uri": uri},
        "options": {"tabSize": 4, "insertSpaces": true}
      }
    })

    check messages.len == 1
    check messages[0]["result"].len == 1
    check messages[0]["result"][0]["newText"].getStr == "function main() {\n}\n"

  test "JSON RPC framing round trips one request":
    let root = freshLspProject("framing")
    defer: removeDir(root)
    let path = root / "rpc.bin"

    let request = %*{
      "jsonrpc": "2.0",
      "id": 7,
      "method": "shutdown"
    }

    var output = open(path, fmWrite)
    writeRpcMessage(output, request)
    output.close()

    var input = open(path, fmRead)
    let decoded = readRpcMessage(input)
    input.close()

    check decoded["id"].getInt == 7
    check decoded["method"].getStr == "shutdown"
