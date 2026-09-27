import std/[os, osproc, strutils, unittest]
import pipeline/[compiler, project_compiler]
import project/model
import source/source_unit
import backend/nim/toolchain/compiler as nimCompiler

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

## Compiles a multi-source Eido project through the real Nim toolchain and returns stdout.
## Example: main.eido can call a function declared in service.eido and execute as one native binary.
proc runNativeProject(project: EidoProject, caseName: string): string =
  let outputPath =
    getTempDir() / ("eido_" & caseName & "_" & $getCurrentProcessId())
  let generatedPath = outputPath & "_generated.nim"

  defer:
    if fileExists(outputPath):
      removeFile(outputPath)
    if fileExists(generatedPath):
      removeFile(generatedPath)

  nimCompiler.compileWithNim(compileProjectToNim(project), outputPath)
  execProcess(outputPath).strip()

suite "Compiler pipeline":
  test "compiles value-returning primitive representations to a native executable":
    # Given
    let source = """
      function boolValue() returns Bool { return true; }
      function byteValue() returns Byte { return 127; }
      function shortValue() returns Short { return 300; }
      function intValue() returns Int { return 2147483648; }
      function floatValue() returns Float { return 123456789.125; }
      function charValue() returns Char { return 'A'; }

      function main() returns Int {
        boolValue();
        byteValue();
        shortValue();
        floatValue();
        charValue();
        return intValue();
      }
    """

    # When
    let output = runNative(source, "primitive_results")

    # Then
    check output == "2147483648"

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


  test "compiles multiple source units into one native executable":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/main.eido", """
        function main() returns Int {
          var account = Account { balance: 42; };
          return read(account);
        }
      """),
      initSourceUnit(1, "src/account.eido", """
        class Account { Int balance; }
        function read(Account account) returns Int { return account.balance; }
      """)
    ])

    # When
    let output = runNativeProject(project, "multi_source")

    # Then
    check output == "42"
