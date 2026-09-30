import std/[strutils, unittest]
import support/compiler_test_support
import compile_time/memory_layout_phase
import pipeline/compiler

suite "Compiler-standard Eido phases":
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

  test "runs Eido layout policy over compiler semantic facts":
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
    let plan = runMemoryLayoutPhase(program)

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

    let generated = compileToNim(source)
    check "StorageInfo" notin generated
    check "Compiler_typeCount" notin generated
    check "MemoryPlan" notin generated
    check "EIDO_CT" notin generated
