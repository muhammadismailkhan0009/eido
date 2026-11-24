## Provides concise compiler-stage entry points for behavior tests.
## Example: `analyzeSource(source)` runs the real lexer, parser, and semantic analyzer.

import frontend/lexer/scanner
import frontend/parser/program_parser
import frontend/ast/program
import hir/program as hirProgram
import semantic/analysis/program_analysis
import source/source_unit
import stdlib/builtin_sources
import backend/nim/emitter/program_emitter

## Parses Eido source through the real lexer and parser.
## Example: `parseSource("function main() {}")` returns the program AST.
proc parseSource*(source: string): Program =
  parseProgram(lexAll(source))

## Parses the real SDK Storage<T> template for compact semantic fixtures while
## preserving the original fixture's source path and offsets.
proc storageSdkProgram(): Program =
  result = parseProgram(lexAll(initSourceUnit(
    1,
    BuiltinStorageSourcePath,
    BuiltinStorageSource,
    BuiltinStorageModuleName, embeddedSdk = true
  )))
  let alignmentSdk = parseProgram(lexAll(initSourceUnit(
    2,
    BuiltinAlignmentSourcePath,
    BuiltinAlignmentSource,
    BuiltinStorageModuleName, embeddedSdk = true
  )))
  result.classes.add alignmentSdk.classes
  for classIndex in 0 ..< result.classes.len:
    result.classes[classIndex].moduleName = BuiltinStorageModuleName
    for methodIndex in 0 ..< result.classes[classIndex].methods.len:
      result.classes[classIndex].methods[methodIndex].moduleName =
        BuiltinStorageModuleName

## Runs Eido source through lexer, parser, and semantic analysis.
## Example: `analyzeSource(source)` returns typed and resolved HIR.
proc analyzeSource*(source: string): hirProgram.HirProgram =
  var parsed = parseSource(source)
  let storageSdk = storageSdkProgram()
  parsed.interfaces.add storageSdk.interfaces
  parsed.classes.add storageSdk.classes
  parsed.functions.add storageSdk.functions
  analyzeProgram(parsed)

## Runs Eido source through semantic analysis and the Nim emitter.
## Example: `emitSource(source)` returns generated Nim without touching the filesystem.
proc emitSource*(source: string): string =
  emitNim(analyzeSource(source))
