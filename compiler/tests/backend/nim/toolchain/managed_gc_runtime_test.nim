import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import pipeline/[options, project_compiler]
import stdlib/builtin_sources
import support/project_fixture_support

## Finds one ordinary generated Eido method by its source-level suffix.
proc generatedMethodName(generated, sourceName: string): string =
  let suffix = "_" & sourceName & "("
  for line in generated.splitLines:
    let stripped = line.strip()
    if stripped.startsWith("proc eido_method_") and suffix in stripped:
      return stripped["proc ".len ..< stripped.find('(')]
  raise newException(ValueError, "missing generated method '" & sourceName & "'")

suite "Managed GC runtime":
  test "generic memory metadata and GC policy are Storage-backed Eido code":
    check "Storage<Byte>.allocateRaw(" in BuiltinManagedHeapAllocatorSource
    check "Storage<Byte>.adoptAddress(" in BuiltinManagedHeapAllocatorSource
    check "Storage<Byte>.release(" in BuiltinManagedHeapAllocatorSource

    check "Storage<Int>.allocate(" in BuiltinMemoryValueRegistrySource
    check "Storage<Bool>.allocate(" in BuiltinMemoryValueRegistrySource
    check "function enter(" in BuiltinMemoryValueRegistrySource
    check "function update(" in BuiltinMemoryValueRegistrySource
    check "function leave(" in BuiltinMemoryValueRegistrySource

    check "Storage<Int>.allocate(" in BuiltinMemoryTypeRegistrySource
    check "function registerType(" in BuiltinMemoryTypeRegistrySource
    check "function setField(" in BuiltinMemoryTypeRegistrySource
    check "fieldContainsIdentity" in BuiltinMemoryTypeRegistrySource

    check "function memoryValueEnter(" in BuiltinMemoryRuntimeSource
    check "function memoryTypeRegister(" in BuiltinMemoryRuntimeSource
    check "function memoryObjectAllocate(" in BuiltinMemoryRuntimeSource
    check "function memoryExecutionBoundary(" in BuiltinMemoryRuntimeSource

    check "MemoryValueRegistry.highWaterMark()" in BuiltinManagedGcRuntimeSource
    check "MemoryTypeRegistry.fieldContainsIdentity(" in BuiltinManagedGcRuntimeSource
    check "MemoryTypeRegistry.fieldOffset(" in BuiltinManagedGcRuntimeSource
    check "ManagedHeapAllocator.allocate(" in BuiltinManagedGcRuntimeSource
    check "ManagedHeapAllocator.release(" in BuiltinManagedGcRuntimeSource
    check "function mark(" in BuiltinManagedGcRuntimeSource
    check "function sweep()" in BuiltinManagedGcRuntimeSource
    check "function collect()" in BuiltinManagedGcRuntimeSource
    check "ManagedGcNative" notin BuiltinManagedGcRuntimeSource
    check "traceAddress" notin BuiltinManagedGcRuntimeSource
    check "destroyAddress" notin BuiltinManagedGcRuntimeSource

  test "class-owned identity slots report generic lifetime before initialization":
    let source = """
      class Box { Int value; }
      class Registry {
        Box Registry.current = Box { value = 42; };
      }
      function main() returns Int { return Registry.current.value; }
    """

    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryPolicy: DefaultMemoryPolicy)
    )

    let valueEnter = generated.find("_memoryValueEnter(int64(0))")
    let initializer = generated.find(
      "eido_class_state_Registry_current = eidoMemoryTemporaryScope("
    )
    let valueUpdate = generated.find(
      "_memoryValueUpdate(eido_class_memory_value_Registry_current"
    )
    check valueEnter >= 0
    check initializer >= 0
    check valueUpdate >= 0
    check valueEnter < initializer
    check initializer < valueUpdate
    check "var eido_class_state_Registry_current: eido_class_Box" in generated
    check "eido_class_state_Registry_current = eidoStorageAllocate" notin generated
    check "eidoStorageRead(eido_class_state_Registry_current" notin generated
    check "runtimeRoot" notin generated
    check "eidoGcPushRoot" notin generated
    check "import eido_managed_gc" notin generated
    check "EidoManagedRef" notin generated
    check " = int64" in generated

  test "generated generic boundary executes Eido mark sweep and reclaims unreachable cycles":
    let source = """
      class Node {
        Node? next;
        Int value;

        function link(Node other) {
          set self.next = ref other;
        }
      }

      function main() returns Int {
        var left = Node { next = none; value = 20; };
        var right = Node { next = none; value = 22; };
        left.link(right);
        right.link(left);
        return left.value + right.value;
      }
    """

    var generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryPolicy: DefaultMemoryPolicy)
    )

    check "_memoryObjectAllocate(" in generated
    check "memoryObjectPayloadOffset" notin generated
    check "template eidoMemoryPayloadAt(T: typedesc, identity: untyped)" in generated
    check "_memoryShutdown()" in generated
    check "_memoryTypeRegister(" in generated
    check "_memoryTypeSetField(" in generated
    check "_memoryValueEnter(" in generated
    check "_memoryExecutionBoundary()" in generated

    # GC policy is present only because the selected Eido runtime implements GC.
    check "_mark(" in generated
    check "_sweep()" in generated
    check "_collect()" in generated

    check "runtimeManaged" notin generated
    check "runtimeRoot" notin generated
    check "runtimeTypeSetReferenceOffset" notin generated
    check "eido_gc_" notin generated
    check "eido_trace_" notin generated
    check "eido_destroy_" notin generated
    check "eidoGcPushRoot" notin generated
    check "_allocateRaw(int64(1)," in generated
    check "_release(eido_local_" in generated

    # The program's generated main runs memory shutdown first. The heap allocator's
    # ordinary generated allocationCount method must then report no live blocks.
    let allocationCountName = generated.generatedMethodName("allocationCount")
    generated.add "\nwhen isMainModule:\n  doAssert " & allocationCountName & "() == 0\n"

    let outputPath =
      getTempDir() / ("eido_managed_gc_runtime_" & $getCurrentProcessId())
    let generatedPath = outputPath & "_generated.nim"
    defer:
      if fileExists(outputPath):
        removeFile(outputPath)
      if fileExists(generatedPath):
        removeFile(generatedPath)

    nimCompiler.compileWithNim(
      generated,
      outputPath,
      generatedSourcePath = generatedPath
    )
    check execProcess(outputPath).strip() == "42"
