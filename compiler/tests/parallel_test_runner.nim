## Compiles the complete test suite once, then executes isolated test selectors in parallel processes.
## Example: compiler suites remain grouped while expensive language feature cases run independently across available cores.

import std/[algorithm, hashes, monotimes, os, osproc, sets, strutils, tables, times]

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
    logPath: string

## Formats elapsed wall-clock time for one completed selector.
proc elapsedLabel(startedAt: MonoTime): string =
  let elapsed = getMonoTime() - startedAt
  formatFloat(elapsed.inMilliseconds.float / 1000.0, ffDecimal, 2) & "s"

## Discovers selectors, compiles the aggregate once, and runs selectors in isolated parallel processes.
## Defaults to half the logical CPUs; an explicit override may use all of them.
proc runTests() =
  let compilerRoot = currentSourcePath().parentDir.parentDir
  let testsRoot = compilerRoot / "tests"
  let projectRoot = compilerRoot.parentDir
  let compilerSourceRoot = compilerRoot / "src"
  let featureRoot = testsRoot / "features"
  let aggregateSource = testsRoot / "compiler_test_suite.nim"
  let nimCompiler = getEnv("NIM", "nim")

  var detectedJobs = countProcessors()
  if detectedJobs <= 0:
    detectedJobs = 1

  let maximumJobs = detectedJobs
  var jobs = max(1, detectedJobs div 2)
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
  var integrationCommands = initTable[string, string]()
  if "--with-integration" in commandLineParams():
    let prefix = quoteShell(nimCompiler) & " r --hints:off --parallelBuild:1"
    let compilerPath = " --path:" & quoteShell(compilerSourceRoot)
    let cliPath = " --path:" & quoteShell(projectRoot / "tools/cli/src")
    let lspPath = " --path:" & quoteShell(projectRoot / "tools/lsp/src")
    let integrationRoot = projectRoot / "tests/integration"
    integrationCommands["Integration::CLI projects"] =
      prefix & cliPath & " " & quoteShell(integrationRoot / "cli_project_test.nim")
    integrationCommands["Integration::Dependency resolution"] =
      prefix & compilerPath & cliPath & " " & quoteShell(integrationRoot / "dependency_resolution_package_test.nim")
    integrationCommands["Integration::Eido CLI dogfood"] =
      prefix & cliPath & " " & quoteShell(integrationRoot / "eido_cli_dogfood_test.nim")
    integrationCommands["Integration::LSP server"] =
      prefix & compilerPath & lspPath & " " & quoteShell(integrationRoot / "lsp_server_test.nim")
    integrationCommands["Integration::TCP networking"] =
      prefix & compilerPath & cliPath & " " & quoteShell(integrationRoot / "tcp_networking_test.nim")
  let filter = getEnv("EIDO_TEST_FILTER")
  if filter.len > 0:
    var matching: seq[string]
    for selector in selectors:
      if filter.toLowerAscii in selector.toLowerAscii: matching.add selector
    selectors = matching
  var integrations: seq[string]
  for name in integrationCommands.keys:
    if filter.len == 0 or filter.toLowerAscii in name.toLowerAscii:
      integrations.add name
  if selectors.len + integrations.len == 0:
    stderr.writeLine("No test selectors match EIDO_TEST_FILTER")
    quit(2)

  # Previous durations are scheduling hints only, never cached test outcomes.
  let timingDir = getCacheDir("eido") / "test-timings"
  createDir(timingDir)
  let timingPath = timingDir / ($hash(testsRoot) & ".tsv")
  var durations = initTable[string, float]()
  if fileExists(timingPath):
    for line in readFile(timingPath).splitLines():
      let fields = line.split('\t')
      if fields.len == 2:
        try: durations[fields[0]] = parseFloat(fields[1])
        except ValueError: discard
  let compareDuration = proc(a, b: string): int =
    let byDuration = cmp(durations.getOrDefault(b), durations.getOrDefault(a))
    if byDuration == 0: cmp(a, b) else: byDuration
  selectors.sort(compareDuration)
  integrations.sort(compareDuration)
  let compilerSelectorCount = selectors.len
  selectors.add integrations

  jobs = min(jobs, max(1, selectors.len))

  let executable =
    getTempDir() / ("eido_test_suite_" & $getCurrentProcessId())

  let logsDir = executable & "_logs"
  createDir(logsDir)
  defer:
    if fileExists(executable): removeFile(executable)
    if dirExists(logsDir): removeDir(logsDir)

  let compileCommand =
    quoteShell(nimCompiler) &
    " c --hints:off --parallelBuild:" & $jobs &
    " -d:nimUnittestOutputLevel:PRINT_FAILURES" &
    " --path:" & quoteShell(compilerSourceRoot) &
    " --path:" & quoteShell(testsRoot) &
    " -o:" & quoteShell(executable) &
    " " & quoteShell(aggregateSource)

  if compilerSelectorCount > 0:
    echo "Compiling complete test suite with ", jobs, " build workers"
    let buildStarted = getMonoTime()
    if execCmd(compileCommand) != 0:
      quit(1)
    echo "Aggregate compiled in ", buildStarted.elapsedLabel()
  let executionStarted = getMonoTime()
  var lastProgress = executionStarted
  var completed = 0

  echo "Running ", compilerSelectorCount, " compiler/feature selectors + ",
    integrations.len, " integration suites with ", jobs, " workers"

  var active: seq[RunningSelector]
  var nextSelector = 0
  var exitCode = 0
  var failedSelectors: seq[string]

  while nextSelector < selectors.len or active.len > 0:
    while nextSelector < selectors.len and active.len < jobs:
      # Keep integration builds separate from the aggregate worker pool.
      # Their independent temporary projects can run together after it drains.
      if nextSelector == compilerSelectorCount and active.len > 0:
        break
      let logPath = logsDir / ($nextSelector & ".log")
      let selector = selectors[nextSelector]
      let invocation =
        if integrationCommands.hasKey(selector): integrationCommands[selector]
        else: quoteShell(executable) & " " & quoteShell(selector)
      # A file, not an unread pipe: verbose failures cannot block a worker.
      let command = invocation & " > " & quoteShell(logPath) & " 2>&1"
      active.add RunningSelector(
        index: nextSelector,
        process: startProcess(command, workingDir = projectRoot,
          options = {poEvalCommand, poParentStreams}),
        startedAt: getMonoTime(),
        logPath: logPath
      )
      inc nextSelector

    var finishedIndex = -1
    while finishedIndex < 0:
      for index, runningSelector in active:
        if not runningSelector.process.running:
          finishedIndex = index
          break
      if finishedIndex < 0:
        if (getMonoTime() - lastProgress).inMilliseconds >= 5000:
          echo "[RUNNING] ", completed, "/", selectors.len, " | active: ",
            active.len, " | failed: ", failedSelectors.len, " | elapsed: ",
            executionStarted.elapsedLabel()
          for worker in active:
            echo "  ", selectors[worker.index], " (", worker.startedAt.elapsedLabel(), ")"
          flushFile(stdout)
          lastProgress = getMonoTime()
        sleep(10)

    let finished = active[finishedIndex]
    let childExitCode = finished.process.waitForExit()
    finished.process.close()
    inc completed
    let selector = selectors[finished.index]
    durations[selector] = (getMonoTime() - finished.startedAt).inMilliseconds.float / 1000.0
    let status = if childExitCode == 0: "PASS" else: "FAIL"
    echo "[", status, "] ", completed, "/", selectors.len, " ", selector,
      " (", finished.startedAt.elapsedLabel(), ")"
    flushFile(stdout)

    if childExitCode != 0:
      failedSelectors.add selectors[finished.index]
      if exitCode == 0:
        exitCode = childExitCode
      if fileExists(finished.logPath):
        stderr.writeLine(readFile(finished.logPath))
    if fileExists(finished.logPath): removeFile(finished.logPath)

    active.delete(finishedIndex)

  var timingText = ""
  for selector, duration in durations:
    timingText.add selector & "\t" & $duration & "\n"
  let temporaryTiming = timingPath & "." & $getCurrentProcessId()
  writeFile(temporaryTiming, timingText)
  moveFile(temporaryTiming, timingPath)

  echo "Test execution took ", executionStarted.elapsedLabel()
  echo "Completed ", selectors.len, " selectors: ",
    selectors.len - failedSelectors.len, " passed, ", failedSelectors.len, " failed"
  if exitCode != 0:
    stderr.writeLine("Failed test selectors:")
    for selector in failedSelectors:
      stderr.writeLine("  " & selector)
    quit(exitCode)

runTests()
