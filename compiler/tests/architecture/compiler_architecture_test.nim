import std/[os, strutils, unittest]

let projectRoot =
  currentSourcePath().parentDir.parentDir.parentDir.parentDir
let compilerRoot = projectRoot / "compiler" / "src"
let testsRoot = projectRoot / "compiler" / "tests"

## Finds Nim source files below one directory.
## Example: `nimSources(compilerRoot / "frontend")` returns lexer/parser/AST source files.
proc nimSources(directory: string): seq[string] =
  for path in walkDirRec(directory):
    if path.endsWith(".nim"):
      result.add path

## Verifies that a compiler capability does not import forbidden outer layers.
## Example: frontend source must not contain an import path into `/backend/`.
proc assertNoDependency(directory: string, forbidden: openArray[string]) =
  for path in nimSources(directory):
    let source = readFile(path)
    for fragment in forbidden:
      check fragment notin source

suite "Compiler architecture":
  test "keeps frontend independent from semantic HIR and backend":
    # Given
    let frontend = compilerRoot / "frontend"

    # When / Then
    assertNoDependency(
      frontend,
      ["/semantic/", "/hir/", "/backend/", "/pipeline/"]
    )

  test "keeps semantic analysis independent from backend and pipeline":
    # Given
    let semantic = compilerRoot / "semantic"

    # When / Then
    assertNoDependency(
      semantic,
      ["/backend/", "/pipeline/"]
    )

  test "keeps HIR independent from frontend and backend":
    # Given
    let hir = compilerRoot / "hir"

    # When / Then
    assertNoDependency(
      hir,
      ["/frontend/", "/backend/", "/pipeline/"]
    )

  test "keeps Nim emission independent from frontend and semantic analysis":
    # Given
    let emitter = compilerRoot / "backend" / "nim" / "emitter"

    # When / Then
    assertNoDependency(
      emitter,
      ["/frontend/", "/semantic/analysis/", "/pipeline/"]
    )

  test "keeps compiler independent from protocol adapters":
    # Given / When / Then
    assertNoDependency(compilerRoot, ["/tools/"])

  test "documents every production procedure":
    # Given
    var productionSources = nimSources(compilerRoot)
    productionSources.add nimSources(projectRoot / "tools")

    # When / Then
    for path in productionSources:
      let lines = readFile(path).splitLines()
      for index, line in lines:
        if line.startsWith("proc "):
          check index > 0
          check lines[index - 1].strip().startsWith("## ")


  test "documents every test helper procedure":
    # Given
    let testSources = nimSources(testsRoot)

    # When / Then
    for path in testSources:
      let lines = readFile(path).splitLines()
      for index, line in lines:
        if line.startsWith("proc "):
          check index > 0
          check lines[index - 1].strip().startsWith("## ")

  test "does not organize tests by feature number":
    # Given
    let testSources = nimSources(testsRoot)

    # When / Then
    for path in testSources:
      check not path.extractFilename.startsWith("test_feature")
