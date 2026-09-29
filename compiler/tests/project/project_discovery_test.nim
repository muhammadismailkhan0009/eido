import std/[os, unittest]
import project/discovery

## Creates an isolated temporary directory for project discovery tests.
proc freshDirectory(name: string): string =
  result = getTempDir() / ("eido_discovery_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "Project discovery":
  test "finds the outermost module manifest from a nested directory":
    let root = freshDirectory("nested")
    defer:
      if dirExists(root):
        removeDir(root)

    createDir(root / "orders")
    createDir(root / "orders" / "internal")
    writeFile(root / "module.yaml", "module: root")
    writeFile(root / "orders" / "module.yaml", "module: orders")

    check findProjectManifest(root / "orders" / "internal") ==
      absolutePath(root / "module.yaml")

  test "fails clearly when no project manifest exists":
    let root = freshDirectory("missing")
    defer:
      if dirExists(root):
        removeDir(root)

    expect ValueError:
      discard findProjectManifest(root)


  test "uses the current directory at call time":
    let root = freshDirectory("cwd")
    let original = getCurrentDir()
    defer:
      setCurrentDir(original)
      if dirExists(root):
        removeDir(root)

    createDir(root / "app")
    writeFile(root / "module.yaml", "module: root")
    writeFile(root / "app" / "module.yaml", "module: app")
    setCurrentDir(root / "app")

    check resolveProjectManifest("") == absolutePath(root / "module.yaml")
