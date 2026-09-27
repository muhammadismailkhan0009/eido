## Resolves the backend support module path used by Eido native functions.
## Example: development builds find stdlib/native/nim while installed SDKs may override it with EIDO_NATIVE_NIM_PATH.

import std/os

## Returns the directory containing the Nim backend native-support module.
## Example: repository builds resolve <repo>/stdlib/native/nim without depending on the caller's current directory when the eido binary lives at repo root.
proc nativeSupportPath*(): string =
  let configured = getEnv("EIDO_NATIVE_NIM_PATH")
  if configured.len > 0:
    return configured

  let appCandidate = getAppDir() / "stdlib" / "native" / "nim"
  if dirExists(appCandidate):
    return appCandidate

  let currentCandidate = getCurrentDir() / "stdlib" / "native" / "nim"
  if dirExists(currentCandidate):
    return currentCandidate

  raise newException(
    OSError,
    "Eido Nim native support was not found; set EIDO_NATIVE_NIM_PATH"
  )
