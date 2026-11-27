## Reuses identical feature-test native binaries, not test results.
## Full Eido semantic analysis and execution still occur on every invocation.
## Dedicated compiler/toolchain tests continue to perform real compilations.
import std/[os, osproc, sha1, times]
import backend/nim/toolchain/[compiler, native_support]

var toolchainIdentity = ""
const compilerInvocation = staticRead("../../src/backend/nim/toolchain/compiler.nim")

## Returns a file identity that invalidates ordinary toolchain upgrades.
proc fileIdentity(path: string): string =
  if path.len > 0 and fileExists(path):
    let info = getFileInfo(path)
    path & ":" & $info.size & ":" & $info.lastWriteTime.toUnix
  else:
    path

## Fingerprints the standard test toolchain and relevant build configuration.
proc nativeTestIdentity(): string =
  if toolchainIdentity.len > 0:
    return toolchainIdentity
  let nim = findExe("nim")
  let gcc = findExe("gcc")
  let nimVersion = execCmdEx(quoteShell(nim) & " --version")
  let gccVersion = execCmdEx(quoteShell(gcc) & " --version")
  if nimVersion.exitCode != 0 or gccVersion.exitCode != 0:
    return ""
  var data = "eido-native-feature-cache-v1\n" & compilerInvocation &
    "\n" & fileIdentity(nim) & nimVersion.output &
    "\n" & fileIdentity(gcc) & gccVersion.output &
    "\n" & getCurrentDir()
  for name in ["PATH", "HOME", "CC", "CFLAGS", "CPPFLAGS", "LDFLAGS",
      "NIMFLAGS", "NIMBLE_DIR", "XDG_CONFIG_HOME", "LIBRARY_PATH", "CPATH",
      "C_INCLUDE_PATH", "GCC_EXEC_PREFIX", "COMPILER_PATH"]:
    data.add "\n" & name & "=" & getEnv(name)
  for path in [getConfigDir() / "nim" / "nim.cfg",
      getHomeDir() / ".nim.cfg", "/etc/nim/nim.cfg",
      getCurrentDir() / "nim.cfg", getCurrentDir() / "config.nims"]:
    if fileExists(path):
      data.add "\n" & path & "\n" & readFile(path)
  let support = nativeSupportPath()
  for name in ["eido_native.nim", "eido_storage.nim", "eido_native_sockets.nim"]:
    let path = support / name
    if not fileExists(path): return ""
    data.add "\n" & path & "\n" & readFile(path)
  toolchainIdentity = $secureHash(data)
  toolchainIdentity

## Compiles a native feature fixture or copies a previously compiled binary.
## Extra inputs include every generated module in a feature batch.
proc compileFeatureNative*(source, outputPath: string,
    generatedSourcePath = "", nimCachePath = "", extraInputs = "") =
  let buildCache = if nimCachePath.len > 0: nimCachePath else: outputPath & "_nimcache"
  defer:
    if nimCachePath.len == 0 and dirExists(buildCache): removeDir(buildCache)
  # Custom SDK/compiler installations can have additional hidden dependencies.
  # Keep their builds uncached. An explicit switch also forces fresh builds.
  let identity =
    if getEnv("EIDO_TEST_NO_CACHE") == "1" or getEnv("NIM").len > 0 or
        getEnv("EIDO_NATIVE_NIM_PATH").len > 0:
      ""
    else:
      nativeTestIdentity()
  if identity.len == 0:
    compileWithNim(source, outputPath, generatedSourcePath = generatedSourcePath,
      nimCachePath = buildCache)
    return
  let key = $secureHash(identity & "\n" & $source.len & ":" & source &
    "\n" & extraInputs)
  let cacheDir = getCacheDir("eido") / "native-feature-tests"
  createDir(cacheDir)
  let cached = cacheDir / (key & ExeExt)
  if fileExists(cached):
    copyFileWithPermissions(cached, outputPath)
    return
  compileWithNim(source, outputPath, generatedSourcePath = generatedSourcePath,
    nimCachePath = buildCache)
  # Publish a complete executable atomically; concurrent builders never expose
  # partially written binaries. The test always executes its own output copy.
  let temporary = cached & "." & $getCurrentProcessId()
  copyFileWithPermissions(outputPath, temporary)
  moveFile(temporary, cached)
