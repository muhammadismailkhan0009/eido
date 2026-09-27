version       = "0.0.1"
author        = "Eido contributors"
description   = "Temporary v0 compiler for the Eido language"
license       = "MIT"
srcDir        = "tools/cli/src"
bin           = @["eido"]

task test, "Run compiler and language feature tests in parallel":
  exec "nim r --hints:off --path:compiler/src --path:compiler/tests compiler/tests/parallel_test_runner.nim"
