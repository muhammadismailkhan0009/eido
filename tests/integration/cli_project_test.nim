import std/[os, osproc, strutils, unittest]
import cli/[arguments, build_command]

suite "CLI project integration":
  test "parses multiple build sources before the output option":
    # Given / When
    let options = parseArgs(@[
      "build", "src/main.eido", "src/account.eido", "-o", "bin/app"
    ])

    # Then
    check options.sourcePaths == @["src/main.eido", "src/account.eido"]
    check options.outputPath == "bin/app"

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
        var account = Account { balance: 42; };
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
