import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import stdlib/builtin_sources

suite "Managed GC runtime":
  test "physical managed allocation delegates to Storage only":
    check "eidoStorageAllocateRaw(" in BuiltinManagedGcSupportSource
    check "alloc0(" notin BuiltinManagedGcSupportSource
    check "dealloc(" notin BuiltinManagedGcSupportSource

  test "marks reachable graphs and sweeps unreachable objects and cycles":
    let outputPath =
      getTempDir() / ("eido_managed_gc_runtime_" & $getCurrentProcessId())
    let generatedPath = outputPath & "_generated.nim"
    defer:
      if fileExists(outputPath):
        removeFile(outputPath)
      if fileExists(generatedPath):
        removeFile(generatedPath)

    let source = """
import eido_managed_gc

type
  Payload = object
    child: EidoManagedRef
    value: int64

## Traces the one managed child field used by this runtime fixture.
proc tracePayload(payloadAddress: pointer) {.nimcall.} =
  eidoGcMark(cast[ptr Payload](payloadAddress)[].child)

## Clears one payload before its Storage backing is released.
proc destroyPayload(payloadAddress: pointer) {.nimcall.} =
  cast[ptr Payload](payloadAddress)[] = default(Payload)

## Allocates one fixture payload through the Eido GC runtime.
proc makePayload(value: int64): EidoManagedRef =
  result = eidoGcAllocate(
    int64(sizeof(Payload)),
    int64(alignof(Payload)),
    tracePayload,
    destroyPayload
  )
  eidoGcPayload[Payload](result)[].value = value

var rootValue = makePayload(1)
var rootNode: EidoGcRoot
eidoGcPushRoot(addr rootNode, addr rootValue)

let child = makePayload(2)
eidoGcPayload[Payload](rootValue)[].child = child

for index in 0 ..< 80:
  discard makePayload(int64(index))

eidoGcCollect()
doAssert eidoGcAllocationCount() == 2
doAssert eidoGcPayload[Payload](rootValue)[].value == 1
doAssert eidoGcPayload[Payload](
  eidoGcPayload[Payload](rootValue)[].child
)[].value == 2

eidoGcPopRoot(addr rootNode)
eidoGcCollect()
doAssert eidoGcAllocationCount() == 0

let cycleA = makePayload(10)
let cycleB = makePayload(20)
eidoGcPayload[Payload](cycleA)[].child = cycleB
eidoGcPayload[Payload](cycleB)[].child = cycleA
doAssert eidoGcAllocationCount() == 2

eidoGcCollect()
doAssert eidoGcAllocationCount() == 0

echo "ok"
"""

    nimCompiler.compileWithNim(source, outputPath)
    check execProcess(outputPath).strip() == "ok"
