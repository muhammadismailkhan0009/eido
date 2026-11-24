import std/[os, osproc, strutils, unittest]
import pipeline/options
import pipeline/project_compiler
import support/project_fixture_support
import backend/nim/toolchain/compiler as nimCompiler
import compile_time/memory_metadata_phase
import tooling/compiler_service
import support/compiler_test_support
import support/feature_test_support

suite "Compile-time layout policy selection":
  test "direct selection activates named offsets and size in canonical metadata":
    let source = """
      class Data { Int first; Byte flag; Int last; }
      layout Reversed for Data {
        var shape = Layout.create();
        shape.field("last");
        shape.field("first");
        shape.field("flag");
        shape.align(32);
        return shape;
      }
      LayoutPolicy.select("Data", "Reversed");
      function main() returns Int {
        var item = Data { first = 21; flag = 1; last = 7; };
        return item.first + item.last;
      }
    """
    let metadata = runMemoryMetadataPhase(analyzeSource(source))
    check metadata.activeLayouts.len == 1
    check metadata.activeLayouts[0].layoutName == "Reversed"
    check metadata.types[0].size == 32
    check metadata.types[0].alignment == 32
    check metadata.types[0].fields[0].fieldName == "last"
    check metadata.types[0].fields[0].offset == 0
    check metadata.types[0].fields[1].fieldName == "first"
    check metadata.types[0].fields[1].offset == 8
    check metadata.types[0].fields[2].offset == 16
    let output = compileProjectToNim(fixtureProject(source))
    check "bytes {.align: 32.}: array[32, byte]" in output
    check "cast[ptr int64](cast[uint](source) + uint(8))[]" in output

  test "selection changes physical inline Storage stride, alignment and field access":
    let source = """
      class Data { Byte flag; Int number; }
      layout Wide for Data {
        var shape = Layout.create();
        shape.field("number");
        shape.fieldAt("flag", 64);
        shape.align(64);
        return shape;
      }
      LayoutPolicy.select("Data", "Wide");
      function main() returns Int {
        var storage = Storage<Data>.allocate(2);
        var address = Storage<Data>.address(storage);
        var stride = Storage<Data>.size();
        var alignment = Storage<Data>.alignment();
        Storage<Data>.write(storage, 0, Data { flag = 3; number = 11; });
        Storage<Data>.write(storage, 1, Data { flag = 4; number = 12; });
        var sum = Storage<Data>.read(storage, 0).number +
                  Storage<Data>.read(storage, 1).number;
        Storage<Data>.release(storage);
        if (stride == 128 and alignment == 64 and
            address - (address / 64) * 64 == 0) {
          return sum;
        }
        return 0;
      }
    """
    check runNativeFeatureSource(source, "layout_storage_wide") == "23"

  test "selected layouts retain GC tracing despite relocated identity fields":
    let source = """
      class Child { Int value; }
      class Parent { Child child; Int number; }
      layout Reversed for Parent {
        var shape = Layout.create();
        shape.field("number");
        shape.field("child");
        return shape;
      }
      LayoutPolicy.select("Parent", "Reversed");
      function main() returns Int {
        var child = Child { value = 91; };
        var parent = Parent { child = ref child; number = 3; };
        var n = 0;
        while (n < 150) {
          var garbage = Child { value = n; };
          set n = n + 1;
        }
        return parent.child.value + parent.number;
      }
    """
    check runNativeFeatureSource(source, "layout_gc_tracing") == "94"

  test "rejects conflicting selections at equal specificity":
    let source = """
      class Data { Int first; Int last; }
      layout A for Data {
        var shape = Layout.create();
        shape.field("first");
        shape.field("last");
        return shape;
      }
      layout B for Data {
        var shape = Layout.create();
        shape.field("last");
        shape.field("first");
        return shape;
      }
      LayoutPolicy.select("Data", "A");
      LayoutPolicy.select("Data", "B");
      function main() {}
    """
    expect ValueError:
      discard runMemoryMetadataPhase(analyzeSource(source))

  test "rejects unknown class and layout names":
    let source = """
      class Data { Int value; }
      layout A for Data {
        var shape = Layout.create();
        shape.field("value");
        return shape;
      }
      LayoutPolicy.select("Data", "Absent");
      function main() {}
    """
    expect ValueError:
      discard runMemoryMetadataPhase(analyzeSource(source))

  test "user-defined class can group compile-time selections":
    let source = """
      class Data { Int value; Byte flag; }
      layout Reverse for Data {
        var shape = Layout.create();
        shape.field("flag");
        shape.field("value");
        return shape;
      }
      class Configuration {
        function useReversed() {
          LayoutPolicy.select("Data", "Reverse");
        }
      }
      Configuration.useReversed();
      function main() returns Int {
        var data = Data { value = 37; flag = 2; };
        return data.value;
      }
    """
    let metadata = runMemoryMetadataPhase(analyzeSource(source))
    check metadata.activeLayouts.len == 1
    check metadata.types[0].fields[0].fieldName == "flag"
    check runNativeFeatureSource(source, "layout_user_config") == "37"

  test "template selection applies to every instantiated specialization":
    let source = """
      class Pair<T> { T value; Byte flag; }
      layout Reverse<U> for Pair<U> {
        var shape = Layout.create();
        shape.field("flag");
        shape.field("value");
        return shape;
      }
      LayoutPolicy.select("Pair", "Reverse");
      function main() returns Int {
        var one = Pair<Int> { value = 4; flag = 1; };
        var two = Pair<Byte> { value = 7; flag = 2; };
        return one.value;
      }
    """
    let metadata = runMemoryMetadataPhase(analyzeSource(source))
    check metadata.activeLayouts.len == 2
    check runNativeFeatureSource(source, "layout_generic_selection") == "4"


  test "concrete generic selection overrides template-level selection":
    let source = """
      class Box<T> { Byte status; T value; }
      layout ValueFirst<U> for Box<U> {
        var shape = Layout.create();
        shape.field("value");
        shape.field("status");
        return shape;
      }
      layout StatusFirst<U> for Box<U> {
        var shape = Layout.create();
        shape.field("status");
        shape.field("value");
        return shape;
      }
      LayoutPolicy.select("Box", "StatusFirst");
      LayoutPolicy.select("Box<Int>", "ValueFirst");
      function main() returns Int {
        var integer = Box<Int> { value = 42; status = 1; };
        var octet = Box<Byte> { value = 7; status = 2; };
        if (integer.value == 42 and octet.status == 2) { return 1; }
        return 0;
      }
    """
    let metadata = runMemoryMetadataPhase(analyzeSource(source))
    check metadata.activeLayouts.len == 2
    for layout in metadata.activeLayouts:
      if layout.className == "Box<Int>":
        check layout.layoutName == "ValueFirst<Int>"
      if layout.className == "Box<Byte>":
        check layout.layoutName == "StatusFirst<Byte>"
    check runNativeFeatureSource(source, "layout_generic_override") == "1"

  test "RC counts moved child reference fields and honors object alignment":
    let source = """
      class Child { Int value; }
      class Parent { Child child; Int number; }
      layout Aligned for Parent {
        var shape = Layout.create();
        shape.field("number");
        shape.field("child");
        shape.align(64);
        return shape;
      }
      LayoutPolicy.select("Parent", "Aligned");
      function main() returns Int {
        var child = Child { value = 89; };
        var parent = Parent { child = ref child; number = 5; };
        var i = 0;
        while (i < 100) {
          var temp = Child { value = i; };
          set i = i + 1;
        }
        return parent.child.value + parent.number;
      }
    """
    let outPath = getTempDir() / ("eido_selected_layout_rc_" & $getCurrentProcessId())
    defer:
      if fileExists(outPath): removeFile(outPath)
    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(memoryPolicy: selectMemoryPolicy("eido.stdlib.memory.rc"))
    )
    check "_alignment = int64(64)" in generated
    nimCompiler.compileWithNim(generated, outPath)
    check execProcess(outPath).strip() == "94"

  test "ordinary construction and inline Storage use the same selected bytes":
    let source = """
      class Account { Int balance; Byte flag; }
      layout NonDefault for Account {
        var shape = Layout.create();
        shape.field("flag");
        shape.fieldAt("balance", 32);
        shape.align(32);
        return shape;
      }
      LayoutPolicy.select("Account", "NonDefault");
      function main() returns Int {
        var original = Account { balance = 24; flag = 5; };
        var slots = Storage<Account>.allocate(2);
        Storage<Account>.write(slots, 0, copy original);
        Storage<Account>.write(slots, 1, Account { balance = 31; flag = 6; });
        var resultValue = Storage<Account>.read(slots, 0).balance +
          Storage<Account>.read(slots, 1).balance + original.balance;
        Storage<Account>.release(slots);
        return resultValue;
      }
    """
    check runNativeFeatureSource(source, "layout_copy_inline") == "79"

  test "zero-field class selection still has physical stride and alignment":
    let source = """
      class Empty {}
      layout AlignedEmpty for Empty {
        var shape = Layout.create();
        shape.align(64);
        return shape;
      }
      LayoutPolicy.select("Empty", "AlignedEmpty");
      function main() returns Int {
        var slots = Storage<Empty>.allocate(2);
        var bytes = Storage<Empty>.size();
        var alignment = Storage<Empty>.alignment();
        var address = Storage<Empty>.address(slots);
        Storage<Empty>.write(slots, 0, Empty {});
        var object = Empty {};
        Storage<Empty>.release(slots);
        if (bytes == 64 and alignment == 64 and
            address - (address / 64) * 64 == 0) { return 1; }
        return 0;
      }
    """
    check runNativeFeatureSource(source, "layout_zero_field") == "1"
