import std/[os, osproc, strutils, unittest]
import backend/nim/toolchain/compiler as nimCompiler
import pipeline/[options, project_compiler]
import project/model
import project/modules/loader

## Creates one isolated module project for memory-policy plugin acceptance tests.
proc freshPolicyProject(name: string): string =
  result = getTempDir() / ("eido_memory_policy_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)
  createDir(result / "policy")

## Writes a minimal class program plus one selectable Eido memory-policy child module.
proc writePolicyFixture(root: string, runtimeSource, policySource: string) =
  writeFile(root / "module.yaml", """
    module: app
    sources:
      - Main.eido
    children:
      policy: { path: policy }
    dependencies: []
    exports: []
    provides: {}
    adopts: []
  """)
  writeFile(root / "Main.eido", """
    class Box { Int value; }
    function main() returns Int {
      var box = Box { value = 7; };
      return box.value;
    }
  """)
  writeFile(root / "policy" / "module.yaml", """
    module: policy
    sources:
      - runtime.eido
    policySources:
      - policy.eido
    children: []
    dependencies: []
    exports: []
    provides: {}
    adopts: []
  """)
  writeFile(root / "policy" / "runtime.eido", runtimeSource)
  writeFile(root / "policy" / "policy.eido", policySource)

suite "User-selectable Eido memory policy modules":
  test "custom policy can acquire class storage directly through Storage":
    let root = freshPolicyProject("custom")
    defer:
      if dirExists(root):
        removeDir(root)

    writePolicyFixture(
      root,
      """
        class CustomMemoryRuntime {
          function acquire(Int payloadSize, Int payloadAlignment, Int typeId) returns Int {
            var backing = Storage<Byte>.allocateRaw(1, payloadSize);
            return Storage<Byte>.address(backing);
          }
        }
      """,
      """
        function main() {
          if (Compiler.typeCount() > 0) {
            MemoryPolicy.objectAcquire("CustomMemoryRuntime.acquire");
          }
        }
      """
    )

    let project = loadModuleProject(root / "module.yaml", ptExecutable)
    let generated = compileProjectToNim(
      project,
      CompilationOptions(
        memoryPolicy: selectMemoryPolicy("app.policy")
      )
    )

    check "ManagedGcRuntime" notin generated
    check "MemoryValueRegistry" notin generated
    check "_acquire(" in generated

    let outputPath = root / "app"
    let generatedPath = root / "app_generated.nim"
    nimCompiler.compileWithNim(generated, outputPath, generatedPath)
    check execProcess(outputPath).strip() == "7"

  test "selected handler must satisfy the generic event signature":
    let root = freshPolicyProject("bad_signature")
    defer:
      if dirExists(root):
        removeDir(root)

    writePolicyFixture(
      root,
      """
        class CustomMemoryRuntime {
          function acquire(Int payloadSize) returns Int {
            var backing = Storage<Byte>.allocateRaw(1, payloadSize);
            return Storage<Byte>.address(backing);
          }
        }
      """,
      """
        function main() {
          MemoryPolicy.objectAcquire("CustomMemoryRuntime.acquire");
        }
      """
    )

    let project = loadModuleProject(root / "module.yaml", ptExecutable)
    expect ValueError:
      discard compileProjectToNim(
        project,
        CompilationOptions(
          memoryPolicy: selectMemoryPolicy("app.policy")
        )
      )

  test "selected policy must provide object acquisition for class storage":
    let root = freshPolicyProject("missing_acquire")
    defer:
      if dirExists(root):
        removeDir(root)

    writePolicyFixture(
      root,
      """
        class CustomMemoryRuntime {
          function noop() {}
        }
      """,
      """
        function main() {}
      """
    )

    let project = loadModuleProject(root / "module.yaml", ptExecutable)
    expect ValueError:
      discard compileProjectToNim(
        project,
        CompilationOptions(
          memoryPolicy: selectMemoryPolicy("app.policy")
        )
      )

  test "selection rejects modules that do not declare policy sources":
    let root = freshPolicyProject("not_policy")
    defer:
      if dirExists(root):
        removeDir(root)

    writePolicyFixture(
      root,
      """
        class CustomMemoryRuntime {
          function noop() {}
        }
      """,
      """
        function main() {}
      """
    )

    let project = loadModuleProject(root / "module.yaml", ptExecutable)
    expect ValueError:
      discard compileProjectToNim(
        project,
        CompilationOptions(
          memoryPolicy: selectMemoryPolicy("app")
        )
      )
