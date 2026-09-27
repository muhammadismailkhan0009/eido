version       = "0.0.1"
author        = "Eido contributors"
description   = "Temporary v0 compiler for the Eido language"
license       = "MIT"
srcDir        = "tools/cli/src"
bin           = @["eido"]

task test, "Run compiler, language, and cross-component integration tests":
  exec "nim r --hints:off --path:compiler/src --path:compiler/tests compiler/tests/parallel_test_runner.nim"
  exec "nim r --hints:off --path:tools/cli/src tests/integration/cli_project_test.nim"
  exec "nim r --hints:off --path:tools/cli/src tests/integration/eido_cli_dogfood_test.nim"
