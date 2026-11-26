import std/unittest
import ../../../../../stdlib/native/nim/eido_storage

suite "Native Storage boundary":
  test "native allocation has zeroed slots and releases the original aligned base":
    var raw = eidoStorageAllocateRaw(1, 63)
    let base = eidoStorageAddress(raw)
    let aligned = ((base + 15) div 16) * 16
    var owned = eidoStorageRebaseOwnedRaw(raw, aligned, 3, 16)
    check eidoStorageAddress(owned) == aligned
    check eidoStorageCapacity(owned) == 3
    var typed = eidoStorageFromRaw[int64](owned)
    check eidoStorageRead(typed, 2) == 0
    eidoStorageWrite(typed, 2, 42'i64)
    check eidoStorageRead(typed, 2) == 42
    eidoStorageRelease(typed)
    check not typed.live
    check typed.data.isNil
    expect AssertionDefect:
      discard eidoStorageRead(typed, 0)

  test "zero count roots can be released without allocating backing":
    var raw = eidoStorageAllocateRaw(0, 8)
    check raw.data.isNil
    check eidoStorageCapacity(raw) == 0
    eidoStorageRelease(raw)
    check not raw.live
    expect AssertionDefect:
      eidoStorageRelease(raw)

  test "borrowed nonempty native region rejects null address":
    expect ValueError:
      discard eidoStorageBorrowAddress(0, 1, 8)
    let empty = eidoStorageBorrowAddress(0, 0, 8)
    check eidoStorageCapacity(empty) == 0

  test "borrowed native region cannot extend outside representable address space":
    let lastAddress = int64(min(uint64(high(uint)), uint64(high(int64))))
    expect ValueError:
      discard eidoStorageBorrowAddress(lastAddress, 1, 2)
    when sizeof(uint) < sizeof(int64):
      expect ValueError:
        discard eidoStorageBorrowAddress(lastAddress + 1, 0, 1)

  test "empty slice cannot wrap around the address space":
    let lastAddress = int64(min(uint64(high(uint)), uint64(high(int64))))
    let edge = eidoStorageBorrowAddress(lastAddress, 1, 1)
    expect ValueError:
      discard eidoStorageSlice(edge, 1, 0)

  test "invalid allocation sizes are rejected before native allocation":
    expect ValueError:
      discard eidoStorageAllocateRaw(-1, 8)
    expect ValueError:
      discard eidoStorageAllocateRaw(1, 0)
    expect ValueError:
      discard eidoStorageAllocateRaw(high(int64), 2)

  test "release of explicit placement preserves parent backing":
    var backing = eidoStorageAllocateRaw(1, 64)
    let address = eidoStorageAddress(backing)
    var placed = eidoStorageReserveAt(backing, address, 8, 1)
    eidoStorageWrite(placed, 0, 37'i8)
    eidoStorageRelease(placed)
    check not placed.live
    check eidoStorageRead(backing, 0) == 37
    var borrowed = eidoStorageBorrowAddress(address, 1, 64)
    expect AssertionDefect:
      eidoStorageRelease(borrowed)
    eidoStorageRelease(backing)


  test "private saved-base release performs native deallocation without descriptor reconstruction":
    let raw = eidoStorageAllocateRaw(1, 32)
    eidoStorageReleaseNativeAddress(eidoStorageAddress(raw))
    expect ValueError:
      eidoStorageReleaseNativeAddress(0)

  test "rebasing at the original address needs no alternate base pointer":
    let raw = eidoStorageAllocateRaw(1, 64)
    var owned = eidoStorageRebaseOwnedRaw(raw, eidoStorageAddress(raw), 4, 8)
    check owned.allocationBase.isNil
    eidoStorageRelease(owned)

  test "native read write and slot identity preserve bounds and liveness checks":
    var raw = eidoStorageAllocateRaw(2, 16)
    var typed = eidoStorageFromRaw[int64](raw)
    let base = eidoStorageAddress(typed)
    check eidoStorageSlotIdentity(typed, 1) == base + 16
    eidoStorageWrite(typed, 1, 73'i64)
    check eidoStorageRead(typed, 1) == 73
    for invalid in [-1'i64, 2'i64]:
      expect IndexDefect:
        discard eidoStorageRead(typed, invalid)
      expect IndexDefect:
        eidoStorageWrite(typed, invalid, 1'i64)
      expect IndexDefect:
        discard eidoStorageSlotIdentity(typed, invalid)
    eidoStorageRelease(typed)
    expect AssertionDefect:
      eidoStorageWrite(typed, 0, 1'i64)
    expect AssertionDefect:
      discard eidoStorageSlotIdentity(typed, 0)
