import std/unittest
import backend/nim/toolchain/artifacts

suite "Nim backend artifacts":
  test "sanitizes generated module names without changing native output names":
    let output = "/tmp/customer-orders"
    check generatedNimPath(output) == "/tmp/customer_orders_generated.nim"

  test "prefixes generated module names that would begin with a digit":
    check generatedNimPath("/tmp/2026-service") ==
      "/tmp/eido_2026_service_generated.nim"
