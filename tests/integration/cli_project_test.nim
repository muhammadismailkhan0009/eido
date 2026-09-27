import std/[os, osproc, strutils, unittest]
import cli/[arguments, build_command, check_command]

suite "CLI project integration":
  test "parses multiple build sources before the output option":
    # Given / When
    let options = parseArgs(@[
      "build", "src/main.eido", "src/account.eido", "-o", "bin/app"
    ])

    # Then
    check options.command == ccBuild
    check options.sourcePaths == @["src/main.eido", "src/account.eido"]
    check options.outputPath == "bin/app"

  test "parses multiple check sources without an output option":
    # Given / When
    let options = parseArgs(@[
      "check", "src/main.eido", "src/account.eido"
    ])

    # Then
    check options.command == ccCheck
    check options.sourcePaths == @["src/main.eido", "src/account.eido"]

  test "rejects an output option for check":
    # Given / When / Then
    expect ValueError:
      discard parseArgs(@["check", "src/main.eido", "-o", "app"])

  test "checks multiple source files without invoking backend compilation":
    # Given
    let stem = getTempDir() / ("eido_cli_check_" & $getCurrentProcessId())
    let mainPath = stem & "_main.eido"
    let accountPath = stem & "_account.eido"
    let generatedPath = stem & "_generated.nim"

    defer:
      for path in [mainPath, accountPath, generatedPath]:
        if fileExists(path):
          removeFile(path)

    writeFile(mainPath, """
      function main() {
        var account = Account { balance = 42; };
        read(account);
      }
    """)
    writeFile(accountPath, """
      class Account { Int balance; }
      function read(Account account) returns Int { return account.balance; }
    """)

    # When
    let result = checkFiles(@[mainPath, accountPath])

    # Then
    check result.success
    check result.diagnostics.len == 0
    check not fileExists(generatedPath)

  test "returns structured diagnostics from check":
    # Given
    let stem = getTempDir() / ("eido_cli_check_error_" & $getCurrentProcessId())
    let mainPath = stem & "_main.eido"

    defer:
      if fileExists(mainPath):
        removeFile(mainPath)

    writeFile(mainPath, "function main() { broken(); }")

    # When
    let result = checkFiles(@[mainPath])

    # Then
    check not result.success
    check result.diagnostics.len == 1
    check result.diagnostics[0].code == "EIDO1000"
    check result.diagnostics[0].span.sourcePath == mainPath

  test "builds multiple Eido source files into one native executable":
    # Given
    let stem = getTempDir() / ("eido_cli_project_" & $getCurrentProcessId())
    let mainPath = stem & "_main.eido"
    let accountPath = stem & "_account.eido"
    let outputPath = stem & "_app"
    let generatedPath = outputPath & "_generated.nim"

    defer:
      for path in [mainPath, accountPath, outputPath, generatedPath]:
        if fileExists(path):
          removeFile(path)

    writeFile(mainPath, """
      function main() returns Int {
        var account = Account { balance = 42; };
        return read(account);
      }
    """)
    writeFile(accountPath, """
      class Account { Int balance; }
      function read(Account account) returns Int { return account.balance; }
    """)

    # When
    buildFiles(@[mainPath, accountPath], outputPath)
    let output = execProcess(outputPath).strip()

    # Then
    check output == "42"
