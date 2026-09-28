## Parses every source unit in an Eido project and assembles one declaration universe.
## Example: classes from account.eido and functions from main.eido become one Program before semantic analysis.

import ../../diagnostics/[codes, errors]
import ../../project/model
import ../ast/program
import ../lexer/scanner
import program_parser

## Parses all project sources independently and merges their top-level declarations.
## Example: source-file order does not limit later cross-file name resolution because analysis sees the complete merged Program.
proc parseProject*(project: EidoProject): Program =
  if project.sources.len == 0:
    fail(EmptyProjectDiagnosticCode, "project must contain at least one source unit")

  for sourceUnit in project.sources:
    var sourceProgram = parseProgram(lexAll(sourceUnit))

    for index in 0 ..< sourceProgram.interfaces.len:
      sourceProgram.interfaces[index].moduleName = sourceUnit.moduleName
      for methodIndex in 0 ..< sourceProgram.interfaces[index].methods.len:
        sourceProgram.interfaces[index].methods[methodIndex].moduleName =
          sourceUnit.moduleName
    for index in 0 ..< sourceProgram.classes.len:
      sourceProgram.classes[index].moduleName = sourceUnit.moduleName
      for methodIndex in 0 ..< sourceProgram.classes[index].methods.len:
        sourceProgram.classes[index].methods[methodIndex].moduleName =
          sourceUnit.moduleName
    for index in 0 ..< sourceProgram.functions.len:
      sourceProgram.functions[index].moduleName = sourceUnit.moduleName

    result.interfaces.add sourceProgram.interfaces
    result.classes.add sourceProgram.classes
    result.functions.add sourceProgram.functions
