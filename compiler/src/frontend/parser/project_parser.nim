## Parses every source unit in an Eido project and assembles one declaration universe.
## Example: classes from account.eido and functions from main.eido become one Program before semantic analysis.

import ../../project/model
import ../ast/program
import ../lexer/scanner
import program_parser

## Parses all project sources independently and merges their top-level declarations.
## Example: source-file order does not limit later cross-file name resolution because analysis sees the complete merged Program.
proc parseProject*(project: EidoProject): Program =
  if project.sources.len == 0:
    raise newException(ValueError, "project must contain at least one source unit")

  for sourceUnit in project.sources:
    let sourceProgram = parseProgram(lexAll(sourceUnit))
    result.classes.add sourceProgram.classes
    result.functions.add sourceProgram.functions
