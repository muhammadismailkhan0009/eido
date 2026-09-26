## Provides concise compiler-stage entry points for behavior tests.
## Example: `analyzeSource(source)` runs the real lexer, parser, and semantic analyzer.

import compiler/frontend/lexer/scanner
import compiler/frontend/parser/program_parser
import compiler/frontend/ast/program
import compiler/hir/program as hirProgram
import compiler/semantic/analysis/program_analysis
import compiler/backend/nim/emitter/program_emitter

## Parses Eido source through the real lexer and parser.
## Example: `parseSource("function main() {}")` returns the program AST.
proc parseSource*(source: string): Program =
  parseProgram(lexAll(source))

## Runs Eido source through lexer, parser, and semantic analysis.
## Example: `analyzeSource(source)` returns typed and resolved HIR.
proc analyzeSource*(source: string): hirProgram.HirProgram =
  analyzeProgram(parseSource(source))

## Runs Eido source through semantic analysis and the Nim emitter.
## Example: `emitSource(source)` returns generated Nim without touching the filesystem.
proc emitSource*(source: string): string =
  emitNim(analyzeSource(source))
