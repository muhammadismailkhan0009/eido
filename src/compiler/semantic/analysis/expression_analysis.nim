## Coordinates expression semantic analysis while semantic families live in focused modules.
## Example: `not count < 10 and ready` dispatches through comparison and Boolean analyzers.

import ../../diagnostics/errors
import ../../frontend/ast/expressions as astExpressions
import ../../hir/expressions as hirExpressions
import ../../types/model
import ../../types/function_result
import ../symbols/functions
import ../symbols/scope

## Resolves names and types in an AST expression and produces HIR.
## Example: source `a + 5` becomes a typed binary HIR node referencing `a` by LocalId.
proc analyzeExpr*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr

## Analyzes an expression against an expected primitive type.
## Example: literal `7` becomes Byte when passed to a Byte parameter, but `128` is rejected.
proc analyzeExprExpected*(
  expr: astExpressions.Expr,
  expected: EidoType,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr

include expression/literal_expressions
include expression/expected_types
include expression/identifier_expressions
include expression/call_expressions
include expression/unary_negation
include expression/arithmetic_operators
include expression/comparison_operators
include expression/boolean_operators

## Resolves names/types and delegates each expression family to its semantic owner.
## Example: literals, calls, unary operators, comparisons, and Boolean operators use focused analyzers.
proc analyzeExpr*(
  expr: astExpressions.Expr,
  locals: LocalScope,
  functions: FunctionSymbols
): hirExpressions.HirExpr =
  case expr.kind
  of astExpressions.ekInteger,
      astExpressions.ekFloat,
      astExpressions.ekBoolean,
      astExpressions.ekChar:
    analyzeLiteral(expr)

  of astExpressions.ekIdentifier:
    analyzeIdentifier(expr, locals)

  of astExpressions.ekCall:
    analyzeValueCall(expr, locals, functions)

  of astExpressions.ekUnary:
    case expr.unaryOp
    of astExpressions.uoNegate:
      analyzeUnaryNegation(expr, locals, functions)
    of astExpressions.uoNot:
      analyzeBooleanNot(expr, locals, functions)

  of astExpressions.ekBinary:
    case expr.op
    of astExpressions.boAnd, astExpressions.boOr:
      analyzeBooleanBinary(expr, locals, functions)
    of astExpressions.boEqual,
        astExpressions.boNotEqual,
        astExpressions.boLess,
        astExpressions.boLessEqual,
        astExpressions.boGreater,
        astExpressions.boGreaterEqual:
      analyzeComparison(expr, locals, functions)
    of astExpressions.boAdd,
        astExpressions.boSubtract,
        astExpressions.boMultiply,
        astExpressions.boDivide:
      analyzeArithmetic(expr, locals, functions)
