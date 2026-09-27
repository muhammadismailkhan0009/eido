## Composes pure compiler phases from source text to generated Nim text. Example: `compileToNim(source)` runs lexing, parsing, semantic analysis, HIR creation, and emission.

import ../frontend/lexer/scanner
import ../frontend/parser/program_parser
import ../semantic/analysis/program_analysis
import ../backend/nim/emitter/program_emitter

## Runs the pure compiler pipeline from Eido source text to Nim source text. Example: `function main() returns Int { return 5; }` becomes a Nim `proc` without touching the filesystem.
proc compileToNim*(source: string): string =
  let tokens = lexAll(source)
  let ast = parseProgram(tokens)
  let hir = analyzeProgram(ast)
  emitNim(hir)
