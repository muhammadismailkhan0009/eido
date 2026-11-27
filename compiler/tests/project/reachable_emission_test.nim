import std/[os, strutils, unittest]
import pipeline/[project_compiler, options]
import support/[project_fixture_support, feature_test_support]
import project/model
import project/modules/loader

suite "Reachable executable emission":
  test "primitive executable does not pull native memory infrastructure":
    let generated = compileProjectToNim(fixtureProject("""
      function main() returns Int { return 2 + 3; }
    """))
    check "import eido_storage" notin generated
    check "AlignedHeapBacking" notin generated
    check "Alignment" notin generated
    check "import eido_native" notin generated

  test "pure Alignment does not pull native allocation":
    let generated = compileProjectToNim(fixtureProject("""
      function main() returns Int { return Alignment.alignUp(17, 8); }
    """))
    check "Alignment_alignUp" in generated
    check "AlignedHeapBacking" notin generated
    check "import eido_storage" notin generated

  test "unreachable functions and static-only classes are not emitted":
    let generated = compileProjectToNim(fixtureProject("""
      class Unused { function value() returns Int { return 99; } }
      function unused() returns Int { return Unused.value(); }
      function used() returns Int { return 42; }
      function main() returns Int { return used(); }
    """))
    check "_unused(" notin generated
    check "eido_class_Unused" notin generated
    check "_used(" in generated

  test "recursive calls and contract dependencies survive reachability":
    let source = """
      function valid(Int value) returns Bool { return value >= 0; }
      function sum(Int n) returns Int {
        require { valid(n); }
        if (n == 0) { return 0; }
        return n + sum(n - 1);
      }
      function main() returns Int { return sum(4); }
    """
    check runFeatureSource(source, "reachable_recursive") == "10"

  test "unused class with eager state initialization is retained":
    let generated = compileProjectToNim(fixtureProject("""
      function initial() returns Int { return 42; }
      class Registry { Int Registry.value = initial(); }
      function main() returns Int { return 0; }
    """))
    check "eido_class_state_Registry_value" in generated
    check "_initial(" in generated

  test "libraries retain declarations for external consumers":
    let generated = compileProjectToNim(fixtureProject("""
      function exportedValue() returns Int { return 42; }
    """, ptLibrary))
    check "_exportedValue(" in generated


  test "ordinary module application omits unused SDK runtime code":
    let root = getTempDir() / ("eido_reachable_module_" & $getCurrentProcessId())
    createDir(root)
    defer: removeDir(root)
    writeFile(root / "module.yaml", """
      module: reachability
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() returns Int { return 5; }")
    let manifest = root / "module.yaml"
    for policy in [DefaultMemoryPolicy, NoMemoryPolicy]:
      let generated = compileProjectToNim(
        loadModuleProject(manifest, ptExecutable),
        CompilationOptions(memoryPolicy: policy)
      )
      check "import eido_storage" notin generated
      check "import eido_native" notin generated
      check "AlignedHeapBacking" notin generated
      check "eido_interface_dispatch_" notin generated
      check "eidoMemoryPayloadAt" notin generated

    # Merely using a stateless SDK API must not pull in unrelated
    # interface declarations, providers or memory policy.
    writeFile(root / "Main.eido", "function main() returns Int { return Alignment.alignUp(17, 8); }")
    let statusOnly = compileProjectToNim(
      loadModuleProject(manifest, ptExecutable),
      CompilationOptions(memoryPolicy: NoMemoryPolicy)
    )
    check "_alignUp(" in statusOnly
    check "import eido_storage" notin statusOnly
    check "eidoMemoryPayloadAt" notin statusOnly

    # A genuinely reachable object-backed provider still needs a policy.
    writeFile(root / "Main.eido", "function main() { var array = Arrays<Int>.create(2); array.release(); }")
    expect ValueError:
      discard compileProjectToNim(
        loadModuleProject(manifest, ptExecutable),
        CompilationOptions(memoryPolicy: NoMemoryPolicy)
      )
    let provider = compileProjectToNim(loadModuleProject(manifest, ptExecutable))
    check "_create(" in provider
    check "eido_interface_dispatch_" in provider
    check "_setAt(" in provider
    check "import eido_storage" in provider
    check "eidoMemoryPayloadAt" in provider

  test "unreachable erroneous declarations still fail semantic validation":
    expect ValueError:
      discard compileProjectToNim(fixtureProject("""
        function invalid() returns Int { return true; }
        function main() returns Int { return 0; }
      """))
