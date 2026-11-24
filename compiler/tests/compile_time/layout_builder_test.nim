import support/project_fixture_support
import pipeline/project_compiler
import std/[strutils, unittest]
import tooling/compiler_service
import pipeline/options
import compile_time/memory_metadata_phase
import support/compiler_test_support

suite "Eido compile-time layout builder":
  test "evaluates multiple layouts independently of active default":
    let program = analyzeSource("""
      class Family {
        Byte code;
        Int children;
        String father;
      }
      layout Reverse for Family {
        var shape = Layout.create();
        shape.field("father");
        shape.field("children");
        shape.field("code");
        return shape;
      }
      layout Aligned for Family {
        var shape = Layout.create();
        shape.field("code");
        shape.field("father");
        shape.field("children");
        shape.align(32);
        return shape;
      }
      function main() {}
    """)
    let metadata = runMemoryMetadataPhase(program)
    check metadata.namedLayouts.len == 2
    let reverse = metadata.namedLayouts[0]
    check reverse.name == "Reverse"
    check reverse.layout.className == "Family"
    check reverse.layout.fields.len == 3
    check reverse.layout.fields[0].fieldName == "father"
    check reverse.layout.fields[0].offset == 0
    check reverse.layout.fields[1].offset == 8
    check reverse.layout.fields[2].offset == 16
    check reverse.layout.size == 24
    let aligned = metadata.namedLayouts[1]
    check aligned.layout.size == 32
    check aligned.layout.alignment == 32
    check metadata.types[0].fields[0].fieldName == "code"
    check metadata.types[0].fields[0].offset == 0

  test "uses Eido expressions, offset queries and explicit placement":
    let program = analyzeSource("""
      class Packed { Byte marker; Int number; }
      layout Gap for Packed {
        var shape = Layout.create();
        shape.field("marker");
        var offset = Layout.alignUp(shape.offsetOf("marker") + 17, 8);
        shape.fieldAt("number", offset);
        shape.align(32);
        return shape;
      }
      function main() {}
    """)
    let selected = runMemoryMetadataPhase(program).namedLayouts[0].layout
    check selected.fields[0].offset == 0
    check selected.fields[1].offset == 24
    check selected.size == 32
    check selected.alignment == 32

  test "rejects overlapping explicit offsets":
    let program = analyzeSource("""
      class Data { Int a; Int b; }
      layout Overlap for Data {
        var shape = Layout.create();
        shape.field("a");
        shape.fieldAt("b", 0);
        return shape;
      }
      function main() {}
    """)
    expect ValueError:
      discard runMemoryMetadataPhase(program)

  test "rejects misaligned explicit offsets":
    let program = analyzeSource("""
      class Data { Byte a; Int b; }
      layout Misaligned for Data {
        var shape = Layout.create();
        shape.field("a");
        shape.fieldAt("b", 1);
        return shape;
      }
      function main() {}
    """)
    expect ValueError:
      discard runMemoryMetadataPhase(program)

  test "rejects unknown fields":
    let program = analyzeSource("""
      class Data { Int a; }
      layout Wrong for Data {
        var shape = Layout.create();
        shape.field("nonexistent");
        return shape;
      }
      function main() {}
    """)
    expect ValueError:
      discard runMemoryMetadataPhase(program)

  test "rejects layouts that omit fields":
    let program = analyzeSource("""
      class Family { Int a; Int b; }
      layout Missing for Family {
        var shape = Layout.create();
        shape.field("a");
        return shape;
      }
      function main() {}
    """)
    expect ValueError:
      discard runMemoryMetadataPhase(program)


  test "specializes and executes named generic layouts":
    let program = analyzeSource("""
      class Box<T> { T value; }
      layout Custom<U> for Box<U> {
        var shape = Layout.create();
        shape.field("value");
        return shape;
      }
      function main() { var box = Box<Int> { value = 42; }; }
    """)
    let metadata = runMemoryMetadataPhase(program)
    check metadata.namedLayouts.len == 1
    check metadata.namedLayouts[0].name == "Custom<Int>"
    check metadata.namedLayouts[0].layout.className == "Box<Int>"
    check metadata.namedLayouts[0].layout.fields[0].offset == 0
    check metadata.namedLayouts[0].layout.size == 8

  test "backend emits opaque class bytes and direct Eido offsets":
    let output = compileProjectToNim(fixtureProject("""
      class Data { Byte marker; Int number; }
      layout Reversed for Data {
        var shape = Layout.create();
        shape.field("number");
        shape.field("marker");
        return shape;
      }
      function main() returns Int {
        var item = Data { marker = 1; number = 42; };
        return item.number;
      }
    """))
    check "bytes {.align: 8.}: array[16, byte]" in output
    check "cast[ptr int64](cast[uint](source) + uint(8))[]" in output
    check "cast[ptr int8](cast[uint](source) + uint(0))[]" in output

  test "layout validation runs without a selected automatic memory policy":
    let plain = compileProjectToNim(fixtureProject("""
      class Marker {}
      layout Empty for Marker {
        var shape = Layout.create();
        return shape;
      }
      function main() {}
    """), CompilationOptions(memoryPolicy: NoMemoryPolicy))
    check plain.len > 0

    expect ValueError:
      discard compileProjectToNim(fixtureProject("""
        class Marker {}
        layout Wrong for Marker {
          var shape = Layout.create();
          shape.field("ghost");
          return shape;
        }
        function main() {}
      """), CompilationOptions(memoryPolicy: NoMemoryPolicy))
