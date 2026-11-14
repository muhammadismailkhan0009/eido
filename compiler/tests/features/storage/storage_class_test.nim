import std/[os, osproc, strutils, unittest]
import support/project_fixture_support
import pipeline/[options, project_compiler]
import backend/nim/toolchain/compiler as nimCompiler
import support/feature_test_support

suite "Storage<Class> inline payloads":
  test "inline class payloads survive GC pressure independently of managed objects":
    let source = """
      class Account {
        Int balance;
      }

      function fill(Storage<Account> slots) {
        Storage<Account>.write(slots, 0, Account { balance = 42; });
        Storage<Account>.write(slots, 1, Account { balance = 11; });
      }

      function main() returns Int {
        var slots = Storage<Account>.allocate(2);
        fill(slots);
        var n = 0;
        while (n < 140) {
          var temporary = Account { balance = n; };
          set n = n + 1;
        }
        var first = ref Storage<Account>.read(slots, 0);
        var second = ref Storage<Account>.read(slots, 1);
        var value = first.balance + second.balance;
        Storage<Account>.release(slots);
        return value;
      }
    """

    check runNativeFeatureSource(source, "storage_class_gc_root") == "53"

  test "class Storage slices borrow the owner but retain access to elements":
    let source = """
      class Account { Int balance; }

      function main() returns Int {
        var slots = Storage<Account>.allocate(3);
        Storage<Account>.write(slots, 2, Account { balance = 39; });
        var tail = Storage<Account>.slice(slots, 2, 1);
        var item = ref Storage<Account>.read(tail, 0);
        var resultValue = item.balance;
        Storage<Account>.release(slots);
        return resultValue;
      }
    """

    check runNativeFeatureSource(source, "storage_class_slice") == "39"

  test "inline Storage frees its entire owned backing":
    let source = """
      class Account { Int balance; }

      function main() returns Int {
        var slots = Storage<Account>.allocate(1);
        Storage<Account>.write(slots, 0, Account { balance = 12; });
        Storage<Account>.release(slots);
        var temporary = Account { balance = 7; };
        return temporary.balance;
      }
    """

    check runNativeFeatureSource(source, "storage_class_release") == "7"

  test "generic class payloads are stored directly":
    let source = """
      class Box<T> {
        T value;
      }

      function main() returns Int {
        var slots = Storage<Box<Int>>.allocate(1);
        Storage<Box<Int>>.write(slots, 0, Box<Int> { value = 29; });
        var box = ref Storage<Box<Int>>.read(slots, 0);
        var resultValue = box.value;
        Storage<Box<Int>>.release(slots);
        return resultValue;
      }
    """

    check runNativeFeatureSource(source, "storage_generic_class") == "29"

  test "reference-counting policy does not own manual inline Storage":
    let source = """
      class Account { Int balance; }

      function fill(Storage<Account> slots) {
        Storage<Account>.write(slots, 0, Account { balance = 77; });
      }

      function main() returns Int {
        var slots = Storage<Account>.allocate(1);
        fill(slots);
        var index = 0;
        while (index < 16) {
          var scratch = Account { balance = index; };
          set index = index + 1;
        }
        var account = ref Storage<Account>.read(slots, 0);
        var balance = account.balance;
        Storage<Account>.release(slots);
        return balance;
      }
    """
    let outputPath = getTempDir() /
      ("eido_storage_class_rc_" & $getCurrentProcessId())
    defer:
      if fileExists(outputPath):
        removeFile(outputPath)
    let generated = compileProjectToNim(
      fixtureProject(source),
      CompilationOptions(
        memoryPolicy: selectMemoryPolicy("eido.stdlib.memory.rc")
      )
    )
    nimCompiler.compileWithNim(generated, outputPath)
    check execProcess(outputPath).strip() == "77"

  test "inline class slots use payload size rather than reference size":
    let source = """
      class Account {
        Int balance;
        Int number;
      }
      function main() returns Int {
        var slots = Storage<Account>.allocate(2);
        var correctSize = Storage<Account>.size() == Storage<Int>.size() * 2;
        var endView = Storage<Account>.slice(slots, 1, 1);
        var contiguous = (
          Storage<Account>.address(endView) -
          Storage<Account>.address(slots)
        ) == Storage<Account>.size();
        Storage<Account>.release(slots);
        if (correctSize and contiguous) { return 1; }
        return 0;
      }
    """
    check runNativeFeatureSource(source, "storage_class_payload_layout") == "1"

  test "ref to inline class mutates the underlying slot":
    let source = """
      class Account {
        Int balance;
        function update(Int value) { set self.balance = value; }
      }
      function main() returns Int {
        var slots = Storage<Account>.allocate(1);
        Storage<Account>.write(slots, 0, Account { balance = 12; });
        var alias = ref Storage<Account>.read(slots, 0);
        alias.update(34);
        var value = Storage<Account>.read(slots, 0).balance;
        Storage<Account>.release(slots);
        return value;
      }
    """
    check runNativeFeatureSource(source, "storage_class_inline_ref") == "34"

  test "explicit copy writes independent inline payload":
    let source = """
      class Account {
        Int balance;
        function update(Int value) { set self.balance = value; }
      }
      function main() returns Int {
        var original = Account { balance = 21; };
        var slots = Storage<Account>.allocate(1);
        Storage<Account>.write(slots, 0, copy original);
        original.update(88);
        var saved = Storage<Account>.read(slots, 0).balance;
        Storage<Account>.release(slots);
        return saved + original.balance;
      }
    """
    check runNativeFeatureSource(source, "storage_class_copy_into") == "109"

  test "class-owned inline Storage is initialized before application class state":
    let source = """
      class Account { Int balance; }
      class Cache {
        Storage<Account> Cache.items = Storage<Account>.allocate(1);
        function store() {
          Storage<Account>.write(Cache.items, 0, Account { balance = 61; });
        }
        function read() returns Int {
          return Storage<Account>.read(Cache.items, 0).balance;
        }
        function close() { Storage<Account>.release(Cache.items); }
      }
      function main() returns Int {
        Cache.store();
        var n = 0;
        while (n < 120) {
          var unused = Account { balance = n; };
          set n = n + 1;
        }
        var value = Cache.read();
        Cache.close();
        return value;
      }
    """
    check runNativeFeatureSource(source, "storage_class_owned_roots") == "61"

  test "copying a class read from Storage creates a detached identity":
    let source = """
      class Account {
        Int balance;
        function change(Int value) { set self.balance = value; }
      }

      function main() returns Int {
        var accounts = Storage<Account>.allocate(1);
        Storage<Account>.write(accounts, 0, Account { balance = 23; });
        var detached = copy Storage<Account>.read(accounts, 0);
        detached.change(42);
        var originalBalance = Storage<Account>.read(accounts, 0).balance;
        Storage<Account>.release(accounts);
        return originalBalance + detached.balance;
      }
    """
    check runNativeFeatureSource(source, "storage_class_copy_read") == "65"

  test "class Storage construction uses its own physical backing":
    let source = """
      class Account { Int balance; }
      function main() returns Int {
        var accounts = Storage<Account>.allocate(1);
        Storage<Account>.write(accounts, 0, Account { balance = 42; });
        var value = Storage<Account>.read(accounts, 0).balance;
        Storage<Account>.release(accounts);
        return value;
      }
    """
    check runNativeFeatureSource(source, "storage_class_raw_backing") == "42"
