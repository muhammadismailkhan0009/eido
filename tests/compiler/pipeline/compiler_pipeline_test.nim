import std/[os, osproc, strutils, unittest]
import compiler/pipeline/compiler
import compiler/backend/nim/toolchain/compiler as nimCompiler

## Compiles Eido source through the real Nim toolchain and returns program stdout.
## Example: a main function returning 30 produces the text `30`.
proc runNative(source: string, caseName: string): string =
  let outputPath =
    getTempDir() / ("eido_" & caseName & "_" & $getCurrentProcessId())
  let generatedPath = outputPath & "_generated.nim"

  defer:
    if fileExists(outputPath):
      removeFile(outputPath)
    if fileExists(generatedPath):
      removeFile(generatedPath)

  nimCompiler.compileWithNim(compileToNim(source), outputPath)
  execProcess(outputPath).strip()

suite "Compiler pipeline":
  test "compiles a value returning program to a native executable":
    # Given
    let source = """
      function add(Int a, Int b) returns Int {
        return a + b;
      }

      function main() returns Int {
        return add(10, 20);
      }
    """

    # When
    let output = runNative(source, "value_result")

    # Then
    check output == "30"

  test "compiles a zero result main to a native executable":
    # Given
    let source = """
      function ping() {}
      function main() {
        ping();
      }
    """

    # When
    let output = runNative(source, "zero_result")

    # Then
    check output == ""


  test "keeps large integer values in Int without a Long suffix":
    # Given
    let source = """
      function main() returns Int {
        return 2147483648;
      }
    """

    # When
    let output = runNative(source, "wide_int")

    # Then
    check output == "2147483648"

  test "keeps decimal values in Float without a Double type or suffix":
    # Given
    let source = """
      function main() returns Float {
        return 123456789.125;
      }
    """

    # When
    let output = runNative(source, "wide_float")

    # Then
    check output == "123456789.125"
