import std/[os, strutils, unittest]
import support/[compiler_test_support, project_fixture_support]
import compile_time/[model, phase_runner]
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

    var sawStableParentIdentity = false
    for typePlan in plan.types:
      if typePlan.className != "Parent":
        continue
      sawStableParentIdentity = true
      check typePlan.fields.len == 3
      check typePlan.fields[2].fieldName == "child"
      check typePlan.fields[2].traced

    check sawStableParentIdentity

  test "GC strategy selects managed parameters locals and receivers as roots":
    let source = """
      class Box {
        Int value;

        function keep(Box other) returns Int {
          var local = Box { value = other.value; };
          return local.value + self.value;
        }
      }

      function consume(Box input) returns Int {
        var localBox = Box { value = input.value; };
        return localBox.value;
      }

      function main() returns Int {
        var box = Box { value = 1; };
        return consume(box);
      }
    """

    let program = analyzeSource(source)
    let plan = runStandardCompileTimePhases(program, msGc)

    var sawFunctionRoots = false
    var sawMethodRoots = false
    for callable in plan.callables:
      if callable.kind == ctkFunction and callable.sourceName == "consume":
        sawFunctionRoots = true
        check callable.roots.len == 2
        check callable.roots[0].sourceName == "input"
        check callable.roots[1].sourceName == "localBox"
      if callable.kind == ctkMethod and callable.sourceName == "keep":
        sawMethodRoots = true
        check callable.roots.len == 3
        check callable.roots[0].sourceName == "receiver"
        check callable.roots[1].sourceName == "other"
        check callable.roots[2].sourceName == "local"

    check sawFunctionRoots
    check sawMethodRoots

  test "GC strategy plan becomes generated backend metadata":
    let source = """
      class Child {
        Int value;
      }

      class Parent {
        Byte tag;
        Int number;
        Child child;
      }

      function main() returns Int {
        var child = Child { value = 7; };
        var parent = Parent {
          tag = 1;
          number = 2;
          child = ref child;
        };
        return parent.child.value;
      }
    """

    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryStrategy: msGc)
    )

    check "eido_class_Parent_gc_payload_size = int64(24)" in generated
    check "eido_class_Parent_gc_alignment = int64(8)" in generated
    check "eido_class_Parent_gc_trace_count = 1" in generated
    check "eido_class_Parent_gc_trace_0_offset = int64(16)" in generated
    check "eido_class_Child_gc_trace_count = 0" in generated
    check "var eido_gc_root_" in generated
    check "eidoGcPushRoot(" in generated
    check "eidoGcPopRoot(" in generated
    check "eidoGcSafepoint()" in generated

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
    check "_gc_payload_size" notin generated
    check "_gc_trace_count" notin generated

  test "manual strategy rejects even zero-field class construction":
    let source = """
      class Token {}

      function main() {
        var token = Token {};
      }
    """

    expect ValueError:
      discard compileProjectToNim(
        fixtureProject(source),
        CompilationOptions(memoryStrategy: msManual)
      )

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
