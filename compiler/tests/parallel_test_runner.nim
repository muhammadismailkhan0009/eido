## Compiles the complete test suite once, then executes isolated test selectors in parallel processes.
## Example: compiler suites remain grouped while expensive language feature cases run independently across available cores.

import std/[algorithm, os, osproc, sets, strutils]

## Extracts a quoted name from a static unittest `suite` or `test` declaration.
## Example: `suite "Arithmetic":` yields `Arithmetic`.
proc unittestName(line, prefix: string): string =
  let stripped = line.strip()
  if not stripped.startsWith(prefix & " \"") or
      not stripped.endsWith("\":"):
    return ""

  stripped[prefix.len + 2 .. ^3]

## Discovers selectors, compiles the aggregate once, and runs selectors in isolated parallel processes.
## Example: EIDO_TEST_JOBS=4 limits both aggregate compilation and selector execution to four workers.
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

  var jobs = max(1, detectedJobs - 2)
  let jobsOverride = getEnv("EIDO_TEST_JOBS")
  if jobsOverride.len > 0:
    try:
      let requestedJobs = parseInt(jobsOverride)
      if requestedJobs > 0:
        jobs = requestedJobs
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

  jobs = min(jobs, selectors.len)

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

  var commands: seq[string]
  for selector in selectors:
    commands.add(
      quoteShell(executable) & " " & quoteShell(selector)
    )

  echo "Running ", compilerSuites.len, " compiler suites + ",
    featureTests.len, " feature tests with ", jobs, " workers"

  proc reportResult(index: int, process: Process) =
    let (lines, childExitCode) = process.readLines()
    if childExitCode != 0:
      stderr.writeLine("FAILED: " & selectors[index])
      for line in lines:
        stderr.writeLine(line)

  let exitCode = execProcesses(
    commands,
    n = jobs,
    options = {poStdErrToStdOut},
    afterRunEvent = reportResult
  )

  if exitCode != 0:
    quit(exitCode)

runTests()
