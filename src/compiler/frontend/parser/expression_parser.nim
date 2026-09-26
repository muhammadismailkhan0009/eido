## Coordinates Eido expression parsing while semantic expression families live in focused modules.
## Example: `not age < 18 and active` flows through Boolean, comparison, arithmetic, unary, and primary modules.

import std/strutils
import ../../source/span
import ../../diagnostics/errors
import ../lexer/token
import ../ast/expressions
import core

## Parses a complete currently-supported expression.
## Example: `salary + bonus * 2 >= limit` returns one precedence-aware AST expression.
proc parseExpression*(parser: var Parser): Expr

## Creates a source span covering both sides of a binary expression.
## Example: the span for `a + 5` starts at `a` and ends after `5`.
proc binarySpan(left, right: Expr): SourceSpan =
  SourceSpan(
    startOffset: left.span.startOffset,
    endOffset: right.span.endOffset,
    line: left.span.line,
    column: left.span.column
  )

include expression/literal_expressions
include expression/call_expressions
include expression/construction_expressions
include expression/grouping_expressions
include expression/primary_expressions
include expression/unary_negation
include expression/arithmetic_operators
include expression/comparison_operators
include expression/boolean_operators

## Parses a complete expression from the lowest-precedence Boolean disjunction layer.
## Example: `not age < 18 and active or admin` follows the full expression precedence chain.
proc parseExpression*(parser: var Parser): Expr =
  parser.parseOr()
