version       = "0.0.1"
author        = "Eido contributors"
description   = "Experimental compiler and project tool for the Eido language"
license       = "MIT"
srcDir        = "tools/cli/src"
bin           = @["eido"]
requires      "nim >= 2.2.0"

task buildLsp, "Build the editor-neutral Eido language server":
  exec "nim c --hints:off --path:compiler/src --path:tools/lsp/src -o:eido-lsp tools/lsp/src/eido_lsp.nim"

task test, "Run compiler, language, and cross-component integration tests":
  exec "nim r --hints:off --path:compiler/src --path:compiler/tests compiler/tests/parallel_test_runner.nim"
  exec "nim r --hints:off --path:tools/cli/src tests/integration/cli_project_test.nim"
  exec "nim r --hints:off --path:tools/cli/src tests/integration/eido_cli_dogfood_test.nim"
  exec "nim r --hints:off --path:compiler/src --path:tools/lsp/src tests/integration/lsp_server_test.nim"
