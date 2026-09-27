import std/[os, osproc, strutils, unittest]
import cli/build_command

## Runs one compiled dogfood CLI command and returns merged output plus exit status.
## Example: version should return ("Eido 0.0.1", 0).
proc runDogfoodCommand(
  executable: string,
  args: seq[string]
): tuple[output: string, exitCode: int] =
  let process = startProcess(
    executable,
    args = args,
    options = {poStdErrToStdOut}
  )
  let (lines, exitCode) = process.readLines()
  process.close()
  (lines.join("\n").strip(), exitCode)

suite "Eido-written CLI dogfood":
  test "builds and runs the permanent CLI shell written in Eido":
    # Given
    let outputPath =
      getTempDir() / ("eido_dogfood_cli_" & $getCurrentProcessId())
    let generatedPath = outputPath & "_generated.nim"
    let sources = @[
      "stdlib/src/process.eido",
      "stdlib/src/console.eido",
      "tools/cli/eido/main.eido"
    ]

    defer:
      if fileExists(outputPath):
        removeFile(outputPath)
      if fileExists(generatedPath):
        removeFile(generatedPath)

    # When
    buildFiles(sources, outputPath)
    let version = runDogfoodCommand(outputPath, @["version"])
    let help = runDogfoodCommand(outputPath, @["help"])
    let unknown = runDogfoodCommand(outputPath, @["unknown"])

    # Then
    check version.exitCode == 0
    check version.output == "Eido 0.0.1"
    check help.exitCode == 0
    check "Usage: eido <command>" in help.output
    check "Commands: help, version" in help.output
    check unknown.exitCode == 1
    check unknown.output == "error: unknown command 'unknown'"
