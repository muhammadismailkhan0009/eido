version       = "0.0.1"
author        = "Eido contributors"
description   = "Temporary v0 compiler for the Eido language"
license       = "MIT"
srcDir        = "src"
bin           = @["eido"]

task test, "Run compiler and language feature tests":
  exec "nim c -r --path:src --path:tests -o:/tmp/eido_compiler_test_suite tests/compiler_test_suite.nim"
