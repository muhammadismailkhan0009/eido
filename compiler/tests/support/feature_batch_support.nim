## Batch successful Eido feature fixtures into one Nim compilation and
## one executable run. Expected runtime failures retain subprocess isolation.
## Every generated Eido program is a separate Nim module with private state.

import std/[os, osproc, strutils]
import backend/nim/toolchain/native_support
import support/feature_native_cache
import pipeline/project_compiler
import support/project_fixture_support

type
  FeatureBatchCase* = object
    name*: string
    source*: string
    expected*: string

  NativeFeatureCase* = FeatureBatchCase
  NativeFeatureResult* = object
    name*: string
    expected*: string
    actual*: string

  FeatureBatchEngine = enum
    fbeNative,
    fbeAuto

var nextBatchSequence = 0

## Convert only the generated standalone entrypoint into an exported callable.
## The compiler's application main body (including policy/string cleanup) stays
## unchanged, and Nim modules continue to own their own globals and methods.
proc reusableModule(source: string): string =
  const entry = "\nwhen isMainModule:\n"
  let entryAt = source.rfind(entry)
  if entryAt < 0:
    raise newException(ValueError, "native batch fixture has no Eido main entrypoint")
  result = source[0 ..< entryAt] & "\nproc eidoFeatureEntry*() =\n" &
    source[entryAt + entry.len .. ^1]

## Compiles each source independently through Eido, then executes their Nim
## modules in one native program (or one VM invocation when supported).
## Markers delimit stdout without assuming a single-line result.
proc runBatch(
  cases: openArray[FeatureBatchCase], batchName: string,
  engine: FeatureBatchEngine
): seq[NativeFeatureResult] =
  if cases.len == 0:
    return @[]

  # Temporary files have a stable single owner; no user application files are modified.
  inc nextBatchSequence
  let batchDir = getTempDir() /
    ("eido_feature_batch_" & $getCurrentProcessId() & "_" & $nextBatchSequence)
  createDir(batchDir)
  defer:
    removeDir(batchDir)

  var runner = ""
  var moduleInputs = ""
  var requiresNative = engine == fbeNative
  for i, feature in cases:
    if feature.name.len == 0:
      raise newException(ValueError, "native batch case must have a name")
    let moduleName = "eido_batch_case_" & $i
    let generated = compileProjectToNim(fixtureProject(feature.source))
    # The Nim VM cannot compile native Storage allocation operations (`alloc0`).
    # Match the same fallback as the ordinary feature-test helper.
    if "import eido_storage" in generated or
        "memoryObjectAllocate" in generated or
        "eido_string_allocate" in generated:
      requiresNative = true
    let moduleSource = reusableModule(generated)
    writeFile(batchDir / (moduleName & ".nim"), moduleSource)
    moduleInputs.add $moduleSource.len & ":" & moduleSource
    runner.add "import " & moduleName & "\n"

  runner.add "\nwhen isMainModule:\n"
  for i in 0 ..< cases.len:
    let mark = "_EIDO_NATIVE_BATCH_" & $i & "_"
    runner.add "  echo \"" & mark & "BEGIN\"\n"
    runner.add "  eido_batch_case_" & $i & ".eidoFeatureEntry()\n"
    runner.add "  echo \"" & mark & "END\"\n"

  let outputPath = batchDir / "batch_executable"
  let runnerPath = batchDir / "batch_runner.nim"
  var execution: tuple[output: string, exitCode: int]
  if requiresNative:
    compileFeatureNative(
      runner,
      outputPath,
      generatedSourcePath = runnerPath,
      nimCachePath = batchDir / "nimcache",
      extraInputs = moduleInputs
    )
    execution = execCmdEx(quoteShell(outputPath))
  else:
    writeFile(runnerPath, runner)
    let cmd = quoteShell(getEnv("NIM", "nim")) &
      " e --hints:off --warnings:off --path:" &
      quoteShell(nativeSupportPath()) & " " & quoteShell(runnerPath)
    execution = execCmdEx(cmd)
  if execution.exitCode != 0:
    var activeCase = "module initialization"
    for i, feature in cases:
      let mark = "_EIDO_NATIVE_BATCH_" & $i & "_"
      if (mark & "BEGIN") in execution.output:
        activeCase = feature.name
      if (mark & "END") in execution.output:
        activeCase = "after '" & feature.name & "'"
    raise newException(OSError,
      "feature batch '" & batchName & "' failed near '" & activeCase &
      "' (exit " & $execution.exitCode & "):\n" & execution.output)

  var cursor = 0
  for i, feature in cases:
    let mark = "_EIDO_NATIVE_BATCH_" & $i & "_"
    let beginAt = execution.output.find(mark & "BEGIN\n", cursor)
    if beginAt < 0:
      raise newException(ValueError,
        "native batch missing start marker for '" & feature.name & "'")
    let contentStart = beginAt + mark.len + "BEGIN\n".len
    let endAt = execution.output.find(mark & "END", contentStart)
    if endAt < 0:
      raise newException(ValueError,
        "native batch missing end marker for '" & feature.name & "'")
    result.add NativeFeatureResult(
      name: feature.name,
      expected: feature.expected,
      actual: execution.output[contentStart ..< endAt].strip()
    )
    cursor = endAt + mark.len + "END".len

## Successful native Eido programs share one native compile and execution.
proc runNativeFeatureBatch*(
  cases: openArray[FeatureBatchCase], batchName: string
): seq[NativeFeatureResult] =
  runBatch(cases, batchName, fbeNative)

## Use one Nim VM invocation when all generated modules support nim e;
## otherwise one native compilation and execution for the whole batch.
proc runFeatureBatch*(
  cases: openArray[FeatureBatchCase], batchName: string
): seq[NativeFeatureResult] =
  runBatch(cases, batchName, fbeAuto)
