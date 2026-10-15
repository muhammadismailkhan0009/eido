import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import pipeline/[options, project_compiler]
import stdlib/builtin_sources
import support/project_fixture_support

suite "Managed GC runtime":
  test "collector delegates physical memory to Eido heap allocator while native bridge never allocates":
    check "Storage<Byte>.allocateRaw(" in BuiltinManagedHeapAllocatorSource
    check "Storage<Byte>.adoptAddress(" in BuiltinManagedHeapAllocatorSource
    check "Storage<Byte>.release(" in BuiltinManagedHeapAllocatorSource
    check "function allocationCount()" in BuiltinManagedHeapAllocatorSource
    check "Int ManagedHeapAllocator.liveBlocks = 0;" in BuiltinManagedHeapAllocatorSource
    check "ManagedHeapAllocator.allocate(" in BuiltinManagedGcRuntimeSource
    check "ManagedHeapAllocator.release(" in BuiltinManagedGcRuntimeSource
    check "Storage<Byte>.allocateRaw(" notin BuiltinManagedGcRuntimeSource
    check "Storage<Byte>.adoptAddress(" notin BuiltinManagedGcRuntimeSource
    check "Storage<Byte>.release(" notin BuiltinManagedGcRuntimeSource
    check "Storage<Byte>.viewAt(" notin BuiltinManagedGcRuntimeSource
    check "Storage<Int>.viewAt(" in BuiltinManagedGcRuntimeSource
    check "Storage<Bool>.viewAt(" in BuiltinManagedGcRuntimeSource
    check "function mark(" in BuiltinManagedGcRuntimeSource
    check "function sweep()" in BuiltinManagedGcRuntimeSource
    check "function collect()" in BuiltinManagedGcRuntimeSource

    check "eidoStorageAllocateRaw(" notin BuiltinManagedGcSupportSource
    check "eidoStorageRelease(" notin BuiltinManagedGcSupportSource
    check "alloc0(" notin BuiltinManagedGcSupportSource
    check "dealloc(" notin BuiltinManagedGcSupportSource
    check "proc eidoGcCollect" notin BuiltinManagedGcSupportSource
    check "proc eidoGcSweep" notin BuiltinManagedGcSupportSource
    check "proc eidoGcMark" notin BuiltinManagedGcSupportSource
    check "EidoManagedAllocation" notin BuiltinManagedGcSupportSource
    check "eido_storage" notin BuiltinManagedGcSupportSource

  test "managed class-owned slots are registered as permanent roots before initialization":
    let source = """
      class Box { Int value; }
      class Registry {
        Box Registry.current = Box { value = 42; };
      }
      function main() returns Int { return Registry.current.value; }
    """

    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryStrategy: msGc)
    )

    let rootPush = generated.find("eidoGcPushRoot(addr eido_class_root_")
    let initializer = generated.find(" = eidoGcProtected(eido_construct_")
    check rootPush >= 0
    check initializer >= 0
    check rootPush < initializer
    check "cast[ptr EidoManagedRef](addr eido_class_state_" in generated

  test "generated runtime executes Eido mark sweep and reclaims unreachable cycles":
    let source = """
      class Node {
        Node? next;
        Int value;

        function link(Node other) {
          set self.next = ref other;
        }
      }

      function main() returns Int {
        var left = Node {
          next = none;
          value = 20;
        };
        var right = Node {
          next = none;
          value = 22;
        };

        left.link(right);
        right.link(left);
        return left.value + right.value;
      }
    """

    var generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryStrategy: msGc)
    )

    check "eido_gc_runtime_allocate(" in generated
    check "eido_gc_runtime_mark(" in generated
    check "eido_gc_runtime_sweep()" in generated
    check "eido_gc_runtime_collect()" in generated
    check "eido_gc_runtime_shutdown()" in generated
    check "_allocateRaw(int64(1)," in generated
    check "_release(eido_local_" in generated

    # The program's generated main runs shutdown first. This backend-only
    # assertion then proves the unreachable cycle was swept by the Eido runtime.
    generated.add """
when isMainModule:
  doAssert eido_gc_runtime_allocationCount() == 0
"""

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
