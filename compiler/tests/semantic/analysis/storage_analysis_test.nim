import std/unittest
import support/compiler_test_support
import types/[method_kind, model, storage]

suite "Storage semantics":
  test "recognizes qualified Storage with qualified class arguments":
    let name = "eido.stdlib.storage.Storage<app.Box>"
    check isConcreteStorageTypeName(name)
    check storageElementName(name) == "app.Box"
    check rawStorageTypeName(name) == "eido.stdlib.storage.Storage<Byte>"
    check isRawStorageTypeName(rawStorageTypeName(name))
    check isConcreteStorageTypeName("Storage<app.Box<app.Item>>")

  test "materializes Eido typed Storage over the raw Byte capability":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(3);
        Storage<Int>.write(storage, 1, 42);
        return Storage<Int>.read(storage, 1);
      }
    """

    let program = analyzeSource(source)

    check program.classes.len == 3
    var storage = program.classes[0]
    for classDecl in program.classes:
      if classDecl.typ == classType("Storage<Int>"):
        storage = classDecl
    check storage.typ == classType("Storage<Int>")
    check storage.fields.len == 0
    check storage.methods.len == 17

    var eidoPublicMethods = 0
    var layoutMethods = 0
    var privateBridges = 0
    var typedStrideFound = false
    for methodDecl in storage.methods:
      check methodDecl.kind == mkStatic
      case methodDecl.sourceName
      of "allocate", "reserveAt", "view", "viewAt", "slice", "capacity", "address",
          "read", "write", "release":
        inc eidoPublicMethods
        check not methodDecl.isNative
      of "strideBytes":
        inc eidoPublicMethods
        typedStrideFound = true
        check not methodDecl.isNative
        check methodDecl.parameters.len == 1
        check methodDecl.parameters[0].typ == classType("Storage<Int>")
        check methodDecl.result.typ == etInt
      of "size", "alignment":
        inc layoutMethods
        check methodDecl.isNative
        check methodDecl.result.typ == etInt
      of "compilerFromRaw", "compilerRaw", "compilerRead", "compilerWrite":
        inc privateBridges
        check methodDecl.isNative
      else:
        check false
    check typedStrideFound
    check eidoPublicMethods == 11
    check layoutMethods == 2
    check privateBridges == 4

    var byteStorage = program.classes[0]
    for classDecl in program.classes:
      if classDecl.typ == classType("Storage<Byte>"):
        byteStorage = classDecl
    check byteStorage.typ == classType("Storage<Byte>")
    check byteStorage.methods.len == 18
    var rawStrideFound = false
    for methodDecl in byteStorage.methods:
      check methodDecl.isNative
      if methodDecl.sourceName == "strideBytes":
        rawStrideFound = true
        check methodDecl.kind == mkStatic
        check methodDecl.parameters.len == 1
        check methodDecl.parameters[0].typ == classType("Storage<Byte>")
        check methodDecl.result.typ == etInt
    check rawStrideFound

  test "supports nominal class payloads in typed Storage":
    let source = """
      class Account { Int balance; }
      function main() returns Int {
        var storage = Storage<Account>.allocate(1);
        Storage<Account>.write(storage, 0, Account { balance = 10; });
        var stored = ref Storage<Account>.read(storage, 0);
        var balance = stored.balance;
        Storage<Account>.release(storage);
        return balance;
      }
    """

    let program = analyzeSource(source)
    check program.classes.len >= 3

  test "supports generic class specializations as Storage elements":
    let source = """
      class Box<T> {
        T value;
      }
      function main() returns Int {
        var values = Storage<Box<Int>>.allocate(1);
        Storage<Box<Int>>.write(values, 0, Box<Int> { value = 5; });
        var entry = ref Storage<Box<Int>>.read(values, 0);
        var value = entry.value;
        Storage<Box<Int>>.release(values);
        return value;
      }
    """
    discard analyzeSource(source)

  test "Storage class writes require explicit relationships":
    let source = """
      class Account { Int balance; }
      function main() {
        var account = Account { balance = 10; };
        var values = Storage<Account>.allocate(1);
        Storage<Account>.write(values, 0, account);
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "inline Storage rejects ref writes because payloads are not pointer slots":
    let source = """
      class Account { Int balance; }
      function main() {
        var original = Account { balance = 10; };
        var values = Storage<Account>.allocate(1);
        Storage<Account>.write(values, 0, ref original);
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "inline Storage allows explicitly copied class payloads":
    let source = """
      class Account { Int balance; }
      function main() {
        var original = Account { balance = 10; };
        var values = Storage<Account>.allocate(1);
        Storage<Account>.write(values, 0, copy original);
        Storage<Account>.release(values);
      }
    """
    discard analyzeSource(source)

  test "inline Storage does not silently copy a temporary class result":
    let source = """
      class Account { Int balance; }
      function makeAccount() returns Account {
        return Account { balance = 2; };
      }
      function main() {
        var values = Storage<Account>.allocate(1);
        Storage<Account>.write(values, 0, makeAccount());
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "Storage class reads require ref or copy for persistent bindings":
    let source = """
      class Account { Int balance; }
      function main() {
        var values = Storage<Account>.allocate(1);
        Storage<Account>.write(values, 0, Account { balance = 10; });
        var account = Storage<Account>.read(values, 0);
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "Storage class raw views borrow existing inline payloads":
    let source = """
      class Account { Int balance; }
      function main() {
        var raw = Storage<Byte>.allocateRaw(2, Storage<Account>.size());
        var accounts = Storage<Account>.view(raw, 0);
        Storage<Account>.write(accounts, 0, Account { balance = 12; });
        Storage<Byte>.release(raw);
      }
    """
    discard analyzeSource(source)

  test "rejects storage of nested owning descriptors":
    let source = """
      function main() {
        var storage = Storage<Storage<Int>>.allocate(1);
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "rejects direct construction of toolchain storage":
    let source = """
      function main() {
        var storage = Storage<Int> {};
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "reserves Storage as a toolchain type constructor":
    let source = """
      class Storage<T> { T value; }
      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)
  test "rejects copy and ref over storage capabilities":
    let copySource = """
      function main() {
        var storage = Storage<Int>.allocate(1);
        var duplicate = copy storage;
      }
    """
    let refSource = """
      function main() {
        var storage = Storage<Int>.allocate(1);
        var alias = ref storage;
      }
    """

    expect ValueError:
      discard analyzeSource(copySource)
    expect ValueError:
      discard analyzeSource(refSource)

  test "a class may own freshly allocated Storage but its graph cannot be copied":
    let validSource = """
      class BufferOwner {
        Storage<Int> storage;
      }

      function main() {
        var owner = BufferOwner {
          storage = Storage<Int>.allocate(2);
        };
      }
    """
    let copySource = """
      class BufferOwner {
        Storage<Int> storage;
      }

      function main() {
        var owner = BufferOwner {
          storage = Storage<Int>.allocate(2);
        };
        var duplicate = copy owner;
      }
    """

    discard analyzeSource(validSource)
    expect ValueError:
      discard analyzeSource(copySource)

  test "borrowed Storage parameters may access but cannot release storage":
    let validSource = """
      function first(Storage<Int> storage) returns Int {
        return Storage<Int>.read(storage, 0);
      }

      function main() returns Int {
        var storage = Storage<Int>.allocate(1);
        Storage<Int>.write(storage, 0, 42);
        var value = first(storage);
        Storage<Int>.release(storage);
        return value;
      }
    """
    let invalidSource = """
      function destroy(Storage<Int> storage) {
        Storage<Int>.release(storage);
      }

      function main() {
        var storage = Storage<Int>.allocate(1);
        destroy(storage);
      }
    """

    discard analyzeSource(validSource)
    expect ValueError:
      discard analyzeSource(invalidSource)

  test "an owning self field may release its Storage":
    let source = """
      class Buffer {
        Storage<Int> storage;

        function close() {
          Storage<Int>.release(self.storage);
        }
      }

      function main() {
        var buffer = Buffer {
          storage = Storage<Int>.allocate(2);
        };
        buffer.close();
      }
    """

    discard analyzeSource(source)

  test "typed views and slices are part of the unified Storage API":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(4, 8);
        var ints = Storage<Int>.view(raw, 0);
        Storage<Int>.write(ints, 2, 21);
        var tail = Storage<Int>.slice(ints, 2, 2);
        var value = Storage<Int>.read(tail, 0);
        Storage<Byte>.release(raw);
        return value;
      }
    """

    let program = analyzeSource(source)
    check program.classes.len == 3

  test "borrowed typed views cannot release backing memory":
    let source = """
      function main() {
        var raw = Storage<Byte>.allocateRaw(2, 8);
        var ints = Storage<Int>.view(raw, 0);
        Storage<Int>.release(ints);
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "borrowAddress storage cannot release backing memory":
    let source = """
      function main() {
        var raw = Storage<Byte>.allocateRaw(1, 8);
        var address = Storage<Byte>.address(raw);
        var borrowed = Storage<Byte>.borrowAddress(address, 1, 8);
        Storage<Byte>.release(borrowed);
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects owner use after release during semantic analysis":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(1);
        Storage<Int>.release(storage);
        return Storage<Int>.read(storage, 0);
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects a borrowed view after its owner is released":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(2, 8);
        var ints = Storage<Int>.view(raw, 0);
        Storage<Byte>.release(raw);
        return Storage<Int>.read(ints, 0);
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "permits raw String views for Storage-backed runtime cleanup":
    let source = """
      function main() {
        var raw = Storage<Byte>.allocateRaw(4, 8);
        var strings = Storage<String>.view(raw, 0);
      }
    """

    discard analyzeSource(source)


  test "user callables may transfer newly owned Storage":
    let source = """
      function create() returns Storage<Int> {
        return Storage<Int>.allocate(2);
      }

      function main() returns Int {
        var storage = create();
        var value = Storage<Int>.read(storage, 0);
        Storage<Int>.release(storage);
        return value;
      }
    """

    discard analyzeSource(source)

  test "borrowed Storage may return but remains borrowed at the caller":
    let validSource = """
      function borrow(Storage<Int> storage) returns Storage<Int> {
        return storage;
      }

      function main() {
        var storage = Storage<Int>.allocate(1);
        var borrowed = borrow(storage);
        Storage<Int>.write(borrowed, 0, 7);
        Storage<Int>.release(storage);
      }
    """
    let invalidReleaseSource = """
      function borrow(Storage<Int> storage) returns Storage<Int> {
        return storage;
      }

      function main() {
        var storage = Storage<Int>.allocate(1);
        var borrowed = borrow(storage);
        Storage<Int>.release(borrowed);
      }
    """

    discard analyzeSource(validSource)
    expect ValueError:
      discard analyzeSource(invalidReleaseSource)

  test "borrowed Storage views cannot escape into owning class fields":
    let source = """
      class Buffer {
        Storage<Int> storage;
      }

      function main() {
        var raw = Storage<Byte>.allocateRaw(2, 8);
        var buffer = Buffer {
          storage = Storage<Int>.view(raw, 0);
        };
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "borrowed Storage callable results cannot escape into owning class fields":
    let source = """
      class Buffer {
        Storage<Int> storage;
      }

      function borrow(Storage<Int> storage) returns Storage<Int> {
        return storage;
      }

      function main() {
        var root = Storage<Int>.allocate(1);
        var buffer = Buffer {
          storage = borrow(root);
        };
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "live owning Storage locals cannot be overwritten without release":
    let source = """
      function main() {
        var storage = Storage<Int>.allocate(1);
        set storage = Storage<Int>.allocate(2);
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects statically provable overlapping explicit Byte reservations":
    let invalid = """
      function main() {
        var region = Storage<Byte>.borrowAddress(4096, 1, 64);
        var first = Storage<Byte>.reserveAt(region, 4096, 16);
        var overlap = Storage<Byte>.reserveAt(region, 4104, 8);
      }
    """
    expect ValueError:
      discard analyzeSource(invalid)

  test "permits reuse after an explicit reservation is released":
    let source = """
      function main() {
        var region = Storage<Byte>.borrowAddress(4096, 1, 64);
        var first = Storage<Byte>.reserveAt(region, 4096, 16);
        Storage<Byte>.release(first);
        var second = Storage<Byte>.reserveAt(region, 4096, 16);
        Storage<Byte>.release(second);
      }
    """
    discard analyzeSource(source)

  test "arbitrary native address adoption is not public API":
    let legacy = """
      function main() {
        var owned = Storage<Byte>.fromAddress(4096, 1, 8);
      }
    """
    let privileged = """
      function main() {
        Storage<Byte>.compilerReleaseNativeAddress(4096);
      }
    """
    expect ValueError:
      discard analyzeSource(legacy)
    expect ValueError:
      discard analyzeSource(privileged)

  test "empty explicit reservations do not claim bytes within live reservations":
    let source = """
      function main() {
        var region = Storage<Byte>.borrowAddress(4096, 1, 64);
        var first = Storage<Byte>.reserveAt(region, 4096, 16);
        var empty = Storage<Byte>.reserveAt(region, 4104, 0);
        Storage<Byte>.release(empty);
        Storage<Byte>.release(first);
      }
    """
    discard analyzeSource(source)

  test "permits a fresh allocation after releasing the previous local owner":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(1, 8);
        Storage<Byte>.release(raw);
        set raw = Storage<Byte>.allocateRaw(1, 8);
        var value = Storage<Byte>.capacity(raw);
        Storage<Byte>.release(raw);
        return value;
      }
    """
    discard analyzeSource(source)

  test "a view remains invalid after its released owner is replaced":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(1, 8);
        var view = Storage<Int>.view(raw, 0);
        Storage<Byte>.release(raw);
        set raw = Storage<Byte>.allocateRaw(1, 8);
        return Storage<Int>.read(view, 0);
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "reassigning a released owner cannot copy another owning descriptor":
    let source = """
      function main() {
        var first = Storage<Int>.allocate(1);
        var second = Storage<Int>.allocate(1);
        Storage<Int>.release(first);
        set first = second;
      }
    """
    expect ValueError:
      discard analyzeSource(source)

  test "explicit placement is invalid after its known backing local is released":
    let source = """
      function main() returns Int {
        var raw = Storage<Byte>.allocateRaw(1, 16);
        var placed = Storage<Int>.reserveAt(raw, Storage<Byte>.address(raw), 1);
        Storage<Byte>.release(raw);
        return Storage<Int>.read(placed, 0);
      }
    """
    expect ValueError:
      discard analyzeSource(source)
