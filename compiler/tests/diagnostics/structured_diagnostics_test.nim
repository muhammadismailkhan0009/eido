import std/unittest
import diagnostics/[formatting, model]
import project/model
import source/source_unit
import tooling/compiler_service

suite "Structured compiler diagnostics":
  test "check result preserves semantic diagnostic code severity message and source span":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/main.eido", "function main() { broken(); }")
    ])

    # When
    let result = checkProject(project)

    # Then
    check not result.success
    check result.diagnostics.len == 1
    check result.diagnostics[0].code == "EIDO1000"
    check result.diagnostics[0].severity == dsError
    check result.diagnostics[0].message == "unknown function 'broken'"
    check result.diagnostics[0].hasSpan
    check result.diagnostics[0].span.sourcePath == "src/main.eido"

  test "missing executable entrypoint is a structured project diagnostic":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/library.eido", "function value() returns Int { return 1; }")
    ])

    # When
    let result = checkProject(project)

    # Then
    check not result.success
    check result.diagnostics.len == 1
    check result.diagnostics[0].code == "EIDO2002"
    check not result.diagnostics[0].hasSpan

  test "successful check retains analyzed HIR for tooling consumers":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/main.eido", "function main() {}")
    ])

    # When
    let result = checkProject(project)

    # Then
    check result.success
    check result.diagnostics.len == 0
    check result.program.functions.len == 1


  test "empty project is a structured project diagnostic":
    # Given
    let project = initProject(ptExecutable, @[])

    # When
    let result = checkProject(project)

    # Then
    check not result.success
    check result.diagnostics.len == 1
    check result.diagnostics[0].code == "EIDO2001"
    check not result.diagnostics[0].hasSpan


  test "human formatting preserves source location severity code and message":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/main.eido", "function main() { broken(); }")
    ])
    let result = checkProject(project)

    # When
    let rendered = formatDiagnostic(result.diagnostics[0])

    # Then
    check rendered ==
      "src/main.eido:1:19 error EIDO1000: unknown function 'broken'"
