## Implements the editor-neutral JSON-RPC framing required by LSP over stdio.

import std/[json, strutils]

## Reads one Content-Length framed JSON-RPC message from a stream.
proc readRpcMessage*(input: File): JsonNode =
  var contentLength = -1
  var line: string

  while input.readLine(line):
    let header = line.strip()
    if header.len == 0:
      break

    let separator = header.find(':')
    if separator < 0:
      continue

    let name = header[0 ..< separator].strip().toLowerAscii()
    let value = header[separator + 1 .. ^1].strip()
    if name == "content-length":
      contentLength = parseInt(value)

  if contentLength < 0:
    return nil

  var payload = newString(contentLength)
  if contentLength > 0:
    let readCount = input.readBuffer(addr payload[0], contentLength)
    if readCount != contentLength:
      return nil

  parseJson(payload)

## Writes one Content-Length framed JSON-RPC message and flushes immediately.
proc writeRpcMessage*(output: File, message: JsonNode) =
  let payload = $message
  output.write("Content-Length: " & $payload.len & "\r\n\r\n")
  output.write(payload)
  output.flushFile()

## Builds one successful JSON-RPC response preserving the caller's id type.
proc rpcResponse*(id, response: JsonNode): JsonNode =
  %*{
    "jsonrpc": "2.0",
    "id": id,
    "result": response
  }

## Builds one JSON-RPC error response.
proc rpcError*(id: JsonNode, code: int, message: string): JsonNode =
  %*{
    "jsonrpc": "2.0",
    "id": id,
    "error": {
      "code": code,
      "message": message
    }
  }

## Builds one JSON-RPC notification.
proc rpcNotification*(methodName: string, params: JsonNode): JsonNode =
  %*{
    "jsonrpc": "2.0",
    "method": methodName,
    "params": params
  }
