import std/[os, osproc, strutils, unittest]
import cli/build_command
import pipeline/options

## Executes the package-owned Eido test binary and returns trimmed output.
proc runPackageTests(executable: string): string =
  execProcess(executable).strip()

suite "Dependency resolution package":
  test "runs identically under tracing GC and reference counting":
    let manifest = "packages/dependency-resolution/tests/module.yaml"
    let gcOutput = getTempDir() / ("eido_dependency_resolution_gc_" & $getCurrentProcessId())
    let rcOutput = getTempDir() / ("eido_dependency_resolution_rc_" & $getCurrentProcessId())
    let gcGenerated = gcOutput & "_generated.nim"
    let rcGenerated = rcOutput & "_generated.nim"

    defer:
      for path in @[gcOutput, rcOutput, gcGenerated, rcGenerated]:
        if fileExists(path):
          removeFile(path)

    buildModuleFile(manifest, gcOutput, gcGenerated, DefaultMemoryPolicy)
    buildModuleFile(
      manifest,
      rcOutput,
      rcGenerated,
      selectMemoryPolicy("eido.stdlib.memory.rc")
    )

    let expected = "dependency-resolution tests passed"
    check runPackageTests(gcOutput) == expected
    check runPackageTests(rcOutput) == expected
