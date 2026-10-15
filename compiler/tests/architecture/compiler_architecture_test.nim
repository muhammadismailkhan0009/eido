import std/[os, strutils, unittest]

let projectRoot =
  currentSourcePath().parentDir.parentDir.parentDir.parentDir
let compilerRoot = projectRoot / "compiler" / "src"
let testsRoot = projectRoot / "compiler" / "tests"

## Finds Nim source files below one directory.
## Example: `nimSources(compilerRoot / "frontend")` returns lexer/parser/AST source files.
proc nimSources(directory: string): seq[string] =
  for path in walkDirRec(directory):
    if path.endsWith(".nim"):
      result.add path

## Verifies that a compiler capability does not import forbidden outer layers.
## Example: frontend source must not contain an import path into `/backend/`.
proc assertNoDependency(directory: string, forbidden: openArray[string]) =
  for path in nimSources(directory):
    let source = readFile(path)
    for fragment in forbidden:
      check fragment notin source

suite "Compiler architecture":
  test "keeps frontend independent from semantic HIR and backend":
    # Given
    let frontend = compilerRoot / "frontend"

    # When / Then
    assertNoDependency(
      frontend,
      ["/semantic/", "/hir/", "/backend/", "/pipeline/"]
    )

  test "keeps semantic analysis independent from backend and pipeline":
    # Given
    let semantic = compilerRoot / "semantic"

    # When / Then
    assertNoDependency(
      semantic,
      ["/backend/", "/pipeline/"]
    )

  test "keeps HIR independent from frontend and backend":
    # Given
    let hir = compilerRoot / "hir"

    # When / Then
    assertNoDependency(
      hir,
      ["/frontend/", "/backend/", "/pipeline/"]
    )

  test "keeps Nim emission independent from frontend and semantic analysis":
    # Given
    let emitter = compilerRoot / "backend" / "nim" / "emitter"

    # When / Then
    assertNoDependency(
      emitter,
      ["/frontend/", "/semantic/analysis/", "/pipeline/"]
    )

  test "keeps compiler independent from protocol adapters":
    # Given / When / Then
    assertNoDependency(compilerRoot, ["/tools/"])

  test "does not identify memory runtime implementation classes":
    # Embedded SDK packaging may name source files; compiler semantics may not
    # recognize or special-case the classes implemented inside those files.
    let packaging = compilerRoot / "stdlib" / "builtin_sources.nim"
    for path in nimSources(compilerRoot):
      if path == packaging:
        continue
      let source = readFile(path)
      for className in [
        "MemoryRuntime",
        "MemoryValueRegistry",
        "MemoryTypeRegistry",
        "ManagedGcRuntime",
        "ManagedHeapAllocator"
      ]:
        check className notin source
    check not fileExists(compilerRoot / "types" / "managed_gc_runtime.nim")
    check not fileExists(compilerRoot / "compile_time" / "gc_memory_strategy.nim")

  test "loads memory policy modules without compiler-owned strategy algorithms":
    let optionsSource = readFile(compilerRoot / "pipeline" / "options.nim")
    let policyPhaseSource = readFile(
      compilerRoot / "compile_time" / "runtime_policy_phase.nim"
    )
    let standardPolicy =
      projectRoot / "stdlib" / "memory" / "managed" / "policy.eido"
    let publicPolicyApi =
      projectRoot / "compiler" / "compile_time" / "api" /
        "memory_policy" / "MemoryPolicy.eido"

    check "MemoryStrategy" notin optionsSource
    check "msGc" notin optionsSource
    check "msManual" notin optionsSource
    check "memory_policy_gc" notin policyPhaseSource
    check "ManagedGcRuntime" notin policyPhaseSource
    check "MemoryValueRegistry" notin policyPhaseSource
    check fileExists(standardPolicy)
    check fileExists(publicPolicyApi)
    check not dirExists(
      projectRoot / "compiler" / "compile_time" / "phases" / "memory_policy_gc"
    )

  test "does not initiate dynamic target allocation outside the Storage API boundary":
    let emitterRoot = compilerRoot / "backend" / "nim" / "emitter"
    for path in nimSources(emitterRoot):
      if path.extractFilename == "storage_support.nim":
        continue
      let source = readFile(path)
      check "eidoStorageAllocate[" notin source
      check "eidoStorageAllocateRaw(" notin source

  test "keeps compiler memory metadata policy-neutral":
    # Memory-specific compiler code may describe identity/layout/lifetime facts,
    # but collector policy words belong only to Eido runtime implementations.
    for relativePath in [
      "compile_time/model.nim",
      "compile_time/instrumentation_model.nim",
      "compile_time/memory_metadata_phase.nim",
      "compile_time/runtime_policy_phase.nim",
      "backend/nim/emitter/memory_metadata_emitter.nim",
      "backend/nim/emitter/instrumentation_emitter.nim",
      "backend/nim/emitter/runtime_bindings.nim",
      "backend/nim/emitter/object_runtime_emitter.nim"
    ]:
      let source = readFile(compilerRoot / relativePath).toLowerAscii()
      for forbidden in ["safepoint", "trace", "root registry", "mark-and-sweep"]:
        check forbidden notin source

  test "documents every production procedure":
    # Given
    var productionSources = nimSources(compilerRoot)
    productionSources.add nimSources(projectRoot / "tools")

    # When / Then
    for path in productionSources:
      let lines = readFile(path).splitLines()
      for index, line in lines:
        if line.startsWith("proc "):
          check index > 0
          check lines[index - 1].strip().startsWith("## ")


  test "documents every test helper procedure":
    # Given
    let testSources = nimSources(testsRoot)

    # When / Then
    for path in testSources:
      let lines = readFile(path).splitLines()
      for index, line in lines:
        if line.startsWith("proc "):
          check index > 0
          check lines[index - 1].strip().startsWith("## ")

  test "does not organize tests by feature number":
    # Given
    let testSources = nimSources(testsRoot)

    # When / Then
    for path in testSources:
      check not path.extractFilename.startsWith("test_feature")
