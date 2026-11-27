import std/[os, osproc, strutils, unittest]
import cli/build_command
import pipeline/options

suite "TCP networking":
  test "real loopback, partial transfers, timeouts and descriptor ownership under GC and RC":
    when defined(linux):
      let manifest = "tests/integration/tcp_networking/module.yaml"
      for policy in [DefaultMemoryPolicy, selectMemoryPolicy("eido.stdlib.memory.rc")]:
        let outputPath = getTempDir() / ("eido_tcp_networking_" & $getCurrentProcessId())
        let generatedPath = outputPath & "_generated.nim"
        try:
          buildModuleFile(manifest, outputPath, generatedPath, policy)
          let result = execCmdEx("python3 tests/integration/tcp_networking/loopback.py " & quoteShell(outputPath))
          checkpoint(result.output)
          check result.exitCode == 0
          check "TCP loopback IPv4/IPv6, errors, lifetimes and timeouts PASS" in result.output
        finally:
          for path in [outputPath, generatedPath]:
            if fileExists(path): removeFile(path)
    else:
      skip()
