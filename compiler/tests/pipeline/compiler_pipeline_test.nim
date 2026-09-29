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
          var account = Account { balance = 42; };
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

  test "native abnormal exit does not run ensure or mask the original failure":
    # Given
    let source = """
      function crash(Int divisor) returns Int {
        return 1 / divisor;
        ensure { false; }
      }

      function main() returns Int {
        return crash(0);
      }
    """
    let outputPath =
      getTempDir() / ("eido_ensure_abnormal_" & $getCurrentProcessId())
    let generatedPath = outputPath & "_generated.nim"
    defer:
      if fileExists(outputPath):
        removeFile(outputPath)
      if fileExists(generatedPath):
        removeFile(generatedPath)

    nimCompiler.compileWithNim(compileToNim(source), outputPath)

    # When
    let execution = execCmdEx(outputPath)

    # Then
    check execution.exitCode != 0
    check "division by zero" in execution.output
    check "ensure contract failed" notin execution.output

  test "native invariant helper evaluation does not recurse":
    # Given
    let source = """
      class Account {
        Int balance;
        invariant { self.valid(); }
        function valid() returns Bool { return self.balance > 0; }
      }
      function main() returns Int {
        var account = Account { balance = 1; };
        return 7;
      }
    """

    # When
    let output = runNative(source, "invariant_helper_native")

    # Then
    check output == "7"

  test "native invariant fails immediately after own field mutation":
    # Given
    let source = """
      class Account {
        Int balance;
        invariant { self.balance > 0; }
        function breakThenRepair() {
          set self.balance = 0;
          set self.balance = 1;
        }
      }
      function main() {
        var account = Account { balance = 1; };
        account.breakThenRepair();
      }
    """
    let outputPath =
      getTempDir() / ("eido_invariant_mutation_" & $getCurrentProcessId())
    let generatedPath = outputPath & "_generated.nim"
    defer:
      if fileExists(outputPath):
        removeFile(outputPath)
      if fileExists(generatedPath):
        removeFile(generatedPath)

    nimCompiler.compileWithNim(compileToNim(source), outputPath)

    # When
    let execution = execCmdEx(outputPath)

    # Then
    check execution.exitCode != 0
    check "invariant contract failed for class 'Account'" in execution.output


  test "native execution binds result across return paths":
    # Given
    let source = """
      function absolute(Int value) returns Int {
        if (value < 0) {
          return -value;
        }
        return value;
        ensure { result >= 0; }
      }

      function main() returns Int {
        return absolute(-5);
      }
    """

    # When
    let output = runNative(source, "ensure_result_native")

    # Then
    check output == "5"
