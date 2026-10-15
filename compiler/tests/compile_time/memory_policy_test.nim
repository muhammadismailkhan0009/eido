import std/[os, strutils, unittest]
import support/[compiler_test_support, project_fixture_support]
import compile_time/[model, phase_runner]
import pipeline/[options, project_compiler]

suite "Compiler-standard Eido memory metadata":
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

    expect ValueError:
      discard analyzeSource("""
        function main() {
          MemoryPolicy.objectAcquire("Runtime.acquire");
        }
      """)

  test "builds policy-neutral object layout and identity-field metadata":
    let source = """
      class Child { Int value; }
      class Parent {
        Byte tag;
        Int number;
        Child child;
      }
      function main() {}
    """

    let program = analyzeSource(source)
    let metadata = runStandardCompileTimePhases(program, DefaultMemoryPolicy)

    check metadata.types.len == 2
    var totalFields = 0
    var identityFields = 0
    var sawAlignedParent = false

    for typeMetadata in metadata.types:
      totalFields += typeMetadata.fields.len
      check typeMetadata.alignment > 0
      check typeMetadata.size >= 0

      if typeMetadata.fields.len == 3:
        sawAlignedParent = true
        check typeMetadata.fields[0].offset == 0
        check typeMetadata.fields[1].offset == 8
        check typeMetadata.fields[2].offset == 16
        check typeMetadata.size == 24
        check typeMetadata.alignment == 8

      for field in typeMetadata.fields:
        if field.containsIdentity:
          inc identityFields

    check sawAlignedParent
    check totalFields == 4
    check identityFields == 1

    var sawStableParentIdentity = false
    for typeMetadata in metadata.types:
      if typeMetadata.className != "Parent":
        continue
      sawStableParentIdentity = true
      check typeMetadata.fields.len == 3
      check typeMetadata.fields[2].fieldName == "child"
      check typeMetadata.fields[2].containsIdentity

    check sawStableParentIdentity

  test "describes identity-valued parameters locals and receivers without selecting roots":
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
    let metadata = runStandardCompileTimePhases(program, DefaultMemoryPolicy)

    var sawFunctionValues = false
    var sawMethodValues = false
    for callable in metadata.callables:
      if callable.kind == ctkFunction and callable.sourceName == "consume":
        sawFunctionValues = true
        check callable.identityValues.len == 2
        check callable.identityValues[0].sourceName == "input"
        check callable.identityValues[1].sourceName == "localBox"
      if callable.kind == ctkMethod and callable.sourceName == "keep":
        sawMethodValues = true
        check callable.identityValues.len == 3
        check callable.identityValues[0].sourceName == "receiver"
        check callable.identityValues[1].sourceName == "other"
        check callable.identityValues[2].sourceName == "local"

    check sawFunctionValues
    check sawMethodValues

  test "generic metadata becomes policy-neutral generated runtime facts":
    let source = """
      class Child { Int value; }
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
      CompilationOptions(memoryPolicy: DefaultMemoryPolicy)
    )

    check "eido_class_Parent_memory_payload_size = int64(24)" in generated
    check "eido_class_Parent_memory_alignment = int64(8)" in generated
    check "eido_class_Parent_memory_type_id" in generated
    check "_memoryTypeRegister(" in generated
    check "_memoryTypeSetField(" in generated
    check "int64(16)" in generated
    check "var eido_memory_value_" in generated
    check "_memoryValueEnter(" in generated
    check "_memoryValueLeave(" in generated
    check "_memoryExecutionBoundary()" in generated

    check "runtimeRoot" notin generated
    check "runtimeManaged" notin generated
    check "runtimeTypeSetReferenceOffset" notin generated
    check "eido_gc_" notin generated
    check "safepoint" notin generated.toLowerAscii()

  test "generic metadata runner contains no memory-management policy":
    let projectRoot = currentSourcePath().parentDir.parentDir.parentDir.parentDir
    let runner = readFile(
      projectRoot / "compiler" / "compile_time" / "phases" /
        "memory_metadata" / "runner.eido"
    )
    let builder = readFile(
      projectRoot / "compiler" / "compile_time" / "phases" /
        "memory_metadata" / "MemoryMetadataBuilder.eido"
    )
    let gcPolicy = readFile(
      projectRoot / "stdlib" / "memory" / "managed" / "policy.eido"
    )
    let bindingResolver = readFile(
      projectRoot / "compiler" / "src" / "backend" / "nim" / "emitter" /
        "runtime_bindings.nim"
    )

    check "MemoryMetadataBuilder.build();" in runner
    check "fieldCount" notin runner
    check "StorageInfo" notin runner
    check "MemoryMetadata.root(" notin builder
    check "MemoryMetadata.trace(" notin builder
    check "safepoint(" notin builder.toLowerAscii()
    check "collect(" notin builder.toLowerAscii()

    # Concrete handler selection belongs to Eido policy, not compiler emission.
    check "memoryValueEnter" in gcPolicy
    check "memoryObjectAllocate" in gcPolicy
    check "memoryExecutionBoundary" in gcPolicy
    check "memoryValueEnter" notin bindingResolver
    check "memoryObjectAllocate" notin bindingResolver
    check "memoryExecutionBoundary" notin bindingResolver

  test "no automatic policy accepts primitive and Storage-only programs":
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
      CompilationOptions(memoryPolicy: NoMemoryPolicy)
    )

    check "when isMainModule" in generated
    check "_memory_payload_size" notin generated
    check "memoryTypeRegister" notin generated

  test "no automatic policy rejects even zero-field class construction":
    let source = """
      class Token {}
      function main() { var token = Token {}; }
    """

    expect ValueError:
      discard compileProjectToNim(
        fixtureProject(source),
        CompilationOptions(memoryPolicy: NoMemoryPolicy)
      )

  test "no automatic policy rejects identity-bearing class declarations":
    let source = """
      class Account { Int balance; }
      function main() { var account = Account { balance = 1; }; }
    """

    expect ValueError:
      discard compileProjectToNim(
        fixtureProject(source),
        CompilationOptions(memoryPolicy: NoMemoryPolicy)
      )

  test "compile-time metadata contracts do not leak into target code":
    let source = """
      class Account { Int balance; }
      function main() { var account = Account { balance = 1; }; }
    """

    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryPolicy: DefaultMemoryPolicy)
    )

    check "StorageInfo" notin generated
    check "Compiler_typeCount" notin generated
    check "MemoryMetadataBuilder" notin generated
    check "EIDO_CT" notin generated
