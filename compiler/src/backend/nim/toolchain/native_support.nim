## Resolves the backend support module path used by Eido native functions.
## Installed compilers carry an embedded fallback, while development SDK layouts may provide the file beside the executable.

import std/os
import ../../../stdlib/builtin_sources

## Materializes the compiler-embedded native support into a temporary SDK cache.
proc materializeEmbeddedNativeSupport(): string =
  let sdkCache = getCacheDir("eido")
  let directory = sdkCache / "native" / "nim"
  createDir(sdkCache)
  createDir(sdkCache / "native")
  createDir(directory)

  let supportFile = directory / "eido_native.nim"
  if not fileExists(supportFile) or readFile(supportFile) != BuiltinNativeSupportSource:
    writeFile(supportFile, BuiltinNativeSupportSource)

  let storageFile = directory / "eido_storage.nim"
  if not fileExists(storageFile) or
      readFile(storageFile) != BuiltinStorageSupportSource:
    writeFile(storageFile, BuiltinStorageSupportSource)
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
