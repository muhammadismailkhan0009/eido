## Renders immutable Eido String values using the current Nim string backend.
## Example: Eido `"hello\\n"` is emitted as a safely escaped Nim string literal.

import std/strutils

## Renders one decoded String literal as valid Nim source text.
proc renderStringLiteral(expr: hirExpressions.HirExpr): string =
  if expr.typ != etString or expr.kind != hirExpressions.hekString:
    raise newException(ValueError, "backend invariant: expected String literal HIR")
  escape(expr.stringValue)

## Renders String `+` as Nim concatenation without exposing backend storage semantics.
proc renderStringConcatenation(expr: hirExpressions.HirExpr): string =
  if expr.typ != etString or expr.op != hirExpressions.hboAdd:
    raise newException(ValueError, "backend invariant: expected String concatenation")
  "(" & renderExpr(expr.left) & " & " & renderExpr(expr.right) & ")"
