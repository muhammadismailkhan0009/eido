import std/unittest
import support/compiler_test_support
import types/[method_kind, model]

suite "Storage semantics":
  test "materializes typed Storage with its toolchain operations":
    let source = """
      function main() returns Int {
        var storage = Storage<Int>.allocate(3);
        Storage<Int>.write(storage, 1, 42);
        return Storage<Int>.read(storage, 1);
      }
    """

    let program = analyzeSource(source)

    check program.classes.len == 2
    var storage = program.classes[0]
    if storage.typ != classType("Storage<Int>"):
      storage = program.classes[1]
    check storage.typ == classType("Storage<Int>")
    check storage.fields.len == 0
    check storage.methods.len == 7
    for methodDecl in storage.methods:
      check methodDecl.isNative
      check methodDecl.kind == mkStatic

    var byteStorage = program.classes[0]
    if byteStorage.typ != classType("Storage<Byte>"):
      byteStorage = program.classes[1]
    check byteStorage.typ == classType("Storage<Byte>")
    check byteStorage.methods.len == 9

  test "rejects nominal element storage until identity ownership is defined":
    let source = """
      class Account { Int balance; }
      function main() {
        var account = Account { balance = 10; };
        var storage = Storage<Account>.allocate(1);
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
    check program.classes.len == 2

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

  test "rejects raw String views until initialization tracking exists":
    let source = """
      function main() {
        var raw = Storage<Byte>.allocateRaw(4, 8);
        var strings = Storage<String>.view(raw, 0);
      }
    """

    expect ValueError:
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

  test "borrowed Storage cannot escape through a function result":
    let source = """
      function borrow(Storage<Int> storage) returns Storage<Int> {
        return storage;
      }

      function main() {}
    """

    expect ValueError:
      discard analyzeSource(source)

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

  test "live owning Storage locals cannot be overwritten without release":
    let source = """
      function main() {
        var storage = Storage<Int>.allocate(1);
        set storage = Storage<Int>.allocate(2);
      }
    """

    expect ValueError:
      discard analyzeSource(source)
