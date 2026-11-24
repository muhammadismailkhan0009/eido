## Compiles the complete test suite once, then executes isolated test selectors in parallel processes.
## Example: compiler suites remain grouped while expensive language feature cases run independently across available cores.

import std/[algorithm, monotimes, os, osproc, sets, strutils, times]

## Extracts a quoted name from a static unittest `suite` or `test` declaration.
## Example: `suite "Arithmetic":` yields `Arithmetic`.
proc unittestName(line, prefix: string): string =
  let stripped = line.strip()
  if not stripped.startsWith(prefix & " \"") or
      not stripped.endsWith("\":"):
    return ""

  stripped[prefix.len + 2 .. ^3]

type
  RunningSelector = object
    index: int
    process: Process
    startedAt: MonoTime

## Formats elapsed wall-clock time for one completed selector.
proc elapsedLabel(startedAt: MonoTime): string =
  let elapsed = getMonoTime() - startedAt
  formatFloat(elapsed.inMilliseconds.float / 1000.0, ffDecimal, 2) & "s"

## Discovers selectors, compiles the aggregate once, and runs selectors in isolated parallel processes.
## EIDO_TEST_JOBS may lower concurrency but never exceed half of detected processors.
proc runTests() =
  let compilerRoot = currentSourcePath().parentDir.parentDir
  let testsRoot = compilerRoot / "tests"
  let compilerSourceRoot = compilerRoot / "src"
  let featureRoot = testsRoot / "features"
  let aggregateSource = testsRoot / "compiler_test_suite.nim"
  let nimCompiler = getEnv("NIM", "nim")

  var detectedJobs = countProcessors()
  if detectedJobs <= 0:
    detectedJobs = 1

  let maximumJobs = max(1, detectedJobs div 2)
  var jobs = maximumJobs
  let jobsOverride = getEnv("EIDO_TEST_JOBS")
  if jobsOverride.len > 0:
    try:
      let requestedJobs = parseInt(jobsOverride)
      if requestedJobs > 0:
        jobs = min(requestedJobs, maximumJobs)
      else:
        raise newException(
          ValueError,
          "EIDO_TEST_JOBS must be a positive integer"
        )
    except ValueError:
      stderr.writeLine("EIDO_TEST_JOBS must be a positive integer")
      quit(2)

  var compilerSuites = initHashSet[string]()
  var featureTests = initHashSet[string]()

  for path in walkDirRec(testsRoot):
    if not path.endsWith("_test.nim"):
      continue

    let isFeature = path.startsWith(featureRoot)
    var currentSuite = ""

    for line in readFile(path).splitLines():
      let suiteName = unittestName(line, "suite")
      if suiteName.len > 0:
        currentSuite = suiteName
        if not isFeature:
          compilerSuites.incl suiteName
        continue

      if isFeature and currentSuite.len > 0:
        let testName = unittestName(line, "test")
        if testName.len > 0:
          featureTests.incl currentSuite & "::" & testName

  var selectors: seq[string]
  for suiteName in compilerSuites:
    selectors.add suiteName & "::"
  for testSelector in featureTests:
    selectors.add testSelector
  selectors.sort()

  jobs = min(jobs, max(1, selectors.len))

  let executable =
    getTempDir() / ("eido_test_suite_" & $getCurrentProcessId())

  defer:
    if fileExists(executable):
      removeFile(executable)

  let compileCommand =
    quoteShell(nimCompiler) &
    " c --hints:off --parallelBuild:" & $jobs &
    " -d:nimUnittestOutputLevel:PRINT_FAILURES" &
    " --path:" & quoteShell(compilerSourceRoot) &
    " --path:" & quoteShell(testsRoot) &
    " -o:" & quoteShell(executable) &
    " " & quoteShell(aggregateSource)

  echo "Compiling complete test suite with ", jobs, " build workers"
  if execCmd(compileCommand) != 0:
    quit(1)

  echo "Running ", compilerSuites.len, " compiler suites + ",
    featureTests.len, " feature tests with ", jobs, " workers"

  var active: seq[RunningSelector]
  var nextSelector = 0
  var exitCode = 0
  var failedSelectors: seq[string]

  while nextSelector < selectors.len or active.len > 0:
    while nextSelector < selectors.len and active.len < jobs:
      active.add RunningSelector(
        index: nextSelector,
        process: startProcess(
          executable,
          args = @[selectors[nextSelector]],
          options = {poStdErrToStdOut}
        ),
        startedAt: getMonoTime()
      )
      inc nextSelector

    var finishedIndex = -1
    while finishedIndex < 0:
      for index, runningSelector in active:
        if not runningSelector.process.running:
          finishedIndex = index
          break
      if finishedIndex < 0:
        sleep(10)

    let finished = active[finishedIndex]
    let (lines, childExitCode) = finished.process.readLines()
    finished.process.close()

    let status = if childExitCode == 0: "PASS" else: "FAIL"
    echo "[", status, "] ", selectors[finished.index], " (", finished.startedAt.elapsedLabel(), ")"

    if childExitCode != 0:
      failedSelectors.add selectors[finished.index]
      if exitCode == 0:
        exitCode = childExitCode
      for line in lines:
        stderr.writeLine(line)

    active.delete(finishedIndex)

  echo "Completed ", selectors.len, " selectors: ",
    selectors.len - failedSelectors.len, " passed, ", failedSelectors.len, " failed"
  if exitCode != 0:
    stderr.writeLine("Failed test selectors:")
    for selector in failedSelectors:
      stderr.writeLine("  " & selector)
    quit(exitCode)

runTests()
