import std/[os, strutils, unittest]
import support/[compiler_test_support, project_fixture_support]
import compile_time/phase_runner
import pipeline/[options, project_compiler]

suite "Compiler-standard Eido memory strategies":
  test "keeps compile-time contracts unavailable to ordinary Eido source":
    expect ValueError:
      discard analyzeSource("""
        function main() returns Int {
          return Compiler.typeCount();
        }
      """)

    expect ValueError:
      discard analyzeSource("""
        function main() returns Int {
          return StorageInfo.sizeOf(0);
        }
      """)

  test "GC strategy runs Eido mark-and-sweep layout policy":
    let source = """
      class Child {
        Int value;
      }

      class Parent {
        Byte tag;
        Int number;
        Child child;
      }

      function main() {}
    """

    let program = analyzeSource(source)
    let plan = runStandardCompileTimePhases(program, msGc)

    check plan.types.len == 2

    var totalFields = 0
    var tracedFields = 0
    var sawAlignedParent = false

    for typePlan in plan.types:
      totalFields += typePlan.fields.len
      check typePlan.alignment > 0
      check typePlan.size >= 0

      if typePlan.fields.len == 3:
        sawAlignedParent = true
        check typePlan.fields[0].offset == 0
        check typePlan.fields[1].offset == 8
        check typePlan.fields[2].offset == 16
        check typePlan.size == 24
        check typePlan.alignment == 8

      for field in typePlan.fields:
        if field.traced:
          inc tracedFields

    check sawAlignedParent
    check totalFields == 4
    check tracedFields == 1

  test "generic runner contains no GC layout policy":
    let projectRoot =
      currentSourcePath().parentDir.parentDir.parentDir.parentDir
    let runner = readFile(
      projectRoot / "compiler" / "compile_time" / "phases" /
        "memory_gc" / "runner.eido"
    )

    check "SelectedMemoryStrategy.plan();" in runner
    check "fieldCount" notin runner
    check "StorageInfo" notin runner
    check "MemoryPlan" notin runner

  test "manual strategy accepts primitive and Storage-only programs":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(2);
        Storage<Int>.write(storage, 0, 42);
        var value = Storage<Int>.read(storage, 0);
        Storage<Int>.release(storage);
        return value;
      }
    """

    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryStrategy: msManual)
    )

    check "when isMainModule" in generated

  test "manual strategy rejects managed class declarations":
    let source = """
      class Account {
        Int balance;
      }

      function main() {
        var account = Account { balance = 1; };
      }
    """

    expect ValueError:
      discard compileProjectToNim(
        fixtureProject(source),
        CompilationOptions(memoryStrategy: msManual)
      )

  test "compile-time strategy contracts do not leak into target code":
    let source = """
      class Account {
        Int balance;
      }

      function main() {
        var account = Account { balance = 1; };
      }
    """

    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryStrategy: msGc)
    )

    check "StorageInfo" notin generated
    check "Compiler_typeCount" notin generated
    check "MemoryPlan" notin generated
    check "SelectedMemoryStrategy" notin generated
    check "EIDO_CT" notin generated
