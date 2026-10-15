import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import pipeline/[options, project_compiler]
import stdlib/builtin_sources
import support/project_fixture_support

proc generatedMethodName(generated, sourceName: string): string =
  let suffix = "_" & sourceName & "("
  for line in generated.splitLines:
    let stripped = line.strip()
    if stripped.startsWith("proc eido_method_") and suffix in stripped:
      return stripped["proc ".len ..< stripped.find('(')]
  raise newException(ValueError, "missing generated method '" & sourceName & "'")

suite "SDK reference-counting runtime":
  test "RC policy is ordinary embedded Eido over Storage":
    check "MemoryPolicy.objectAcquire" in BuiltinRcPolicySource
    check "Storage<Byte>.allocateRaw(" in BuiltinRcRuntimeSource
    check "Storage<Byte>.adoptAddress(" in BuiltinRcRuntimeSource
    check "function recount()" in BuiltinRcRuntimeSource
    check "function reclaimAcyclic(" in BuiltinRcRuntimeSource
    check "native function" notin BuiltinRcRuntimeSource
    check "ManagedGcRuntime" notin BuiltinRcRuntimeSource

  test "selected SDK RC reclaims acyclic objects before shutdown":
    let source = """
      class Child { Int value; }
      class Parent { Child child; }

      function build() returns Int {
        var child = Child { value = 42; };
        var parent = Parent { child = ref child; };
        return parent.child.value;
      }

      function main() returns Int {
        var answer = build();
        return answer;
      }
    """

    var generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryPolicy: selectMemoryPolicy(BuiltinRcModuleName))
    )

    check "RcRuntime" in generated
    check "ManagedGcRuntime" notin generated
    check "MemoryValueRegistry" notin generated
    check "_objectAcquire(" in generated
    check "_executionBoundary()" in generated

    let allocationCount = generated.generatedMethodName("allocationCount")
    let reclaimedCount = generated.generatedMethodName("boundaryReclaimedCount")
    let forcedCount = generated.generatedMethodName("forcedShutdownCount")
    generated.add "\nwhen isMainModule:\n"
    generated.add "  doAssert " & allocationCount & "() == 0\n"
    generated.add "  doAssert " & reclaimedCount & "() == 2\n"
    generated.add "  doAssert " & forcedCount & "() == 0\n"

    let outputPath = getTempDir() / ("eido_rc_runtime_" & $getCurrentProcessId())
    let generatedPath = outputPath & "_generated.nim"
    defer:
      if fileExists(outputPath): removeFile(outputPath)
      if fileExists(generatedPath): removeFile(generatedPath)

    nimCompiler.compileWithNim(
      generated,
      outputPath,
      generatedSourcePath = generatedPath
    )
    check execProcess(outputPath).strip() == "42"
