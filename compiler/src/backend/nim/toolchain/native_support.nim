## Resolves the backend support module path used by Eido native functions.
## Installed compilers carry an embedded fallback, while development SDK layouts may provide the file beside the executable.

import std/[os, hashes]
import ../../../stdlib/builtin_sources

## Publishes one complete immutable source file even when compilers run concurrently.
proc publishEmbeddedSource(path, source: string) =
  if fileExists(path) and readFile(path) == source:
    return
  let temporary = path & "." & $getCurrentProcessId()
  writeFile(temporary, source)
  moveFile(temporary, path)

## Materializes the compiler-embedded native support into a content-versioned SDK cache.
proc materializeEmbeddedNativeSupport(): string =
  let sdkCache = getCacheDir("eido")
  let directory = sdkCache / "native" / ("nim-" & $hash(BuiltinNativeSupportSource & BuiltinStorageSupportSource))
  createDir(sdkCache)
  createDir(sdkCache / "native")
  createDir(directory)

  let supportFile = directory / "eido_native.nim"
  publishEmbeddedSource(supportFile, BuiltinNativeSupportSource)

  let storageFile = directory / "eido_storage.nim"
  publishEmbeddedSource(storageFile, BuiltinStorageSupportSource)

  directory

## Returns the directory containing the Nim backend native-support module.
## `EIDO_NATIVE_NIM_PATH` remains an explicit SDK/development override.
proc nativeSupportPath*(): string =
  let configured = getEnv("EIDO_NATIVE_NIM_PATH")
  if configured.len > 0:
    return configured

  let appCandidate = getAppDir() / "stdlib" / "native" / "nim"
  if dirExists(appCandidate):
    return appCandidate

  materializeEmbeddedNativeSupport()
