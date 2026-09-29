import std/[os, strutils, unittest]
import backend/nim/toolchain/native_support

suite "Installed native support":
  test "materializes embedded native support without repository-relative files":
    let originalDirectory = getCurrentDir()
    let originalOverride = getEnv("EIDO_NATIVE_NIM_PATH")
    let isolated = getTempDir() / ("eido_native_support_" & $getCurrentProcessId())
    if dirExists(isolated):
      removeDir(isolated)
    createDir(isolated)

    defer:
      setCurrentDir(originalDirectory)
      if originalOverride.len > 0:
        putEnv("EIDO_NATIVE_NIM_PATH", originalOverride)
      else:
        delEnv("EIDO_NATIVE_NIM_PATH")
      if dirExists(isolated):
        removeDir(isolated)

    delEnv("EIDO_NATIVE_NIM_PATH")
    setCurrentDir(isolated)
    let path = nativeSupportPath()

    check fileExists(path / "eido_native.nim")
    check readFile(path / "eido_native.nim").contains("eido_native_method_Console_writeLine")
