## Sound, deliberately limited static overlap checks for direct literal
## Storage<Byte>.reserveAt calls in straight-line callable bodies. No runtime
## registry is introduced, and unknown/dynamic placements are not guessed.

import ../../diagnostics/errors
import ../../frontend/ast/[declarations, expressions, statements, program]
import ../../types/storage

type
  StaticClaim = object
    region: string
    variable: string
    first: int64
    last: int64

## Only nonnegative integer literals are compile-time-known in this pass.
proc literalNonnegative(expr: Expr): int64 =
  if expr.isNil or expr.kind != ekInteger or expr.intValue < 0:
    return -1
  expr.intValue

## Analyze only unconditional statements in this callable. Branching and
## runtime-computed values belong to a future data-flow analysis.
proc checkStraightLineReservations(body: seq[Stmt]) =
  var claims: seq[StaticClaim]
  for statement in body:
    var expr: Expr
    var variable = ""
    case statement.kind
    of skVar:
      expr = statement.initializer
      variable = statement.name
    of skCall:
      expr = statement.call
    else:
      continue

    if expr.isNil or expr.kind != ekMethodCall or
        expr.receiver.kind != ekIdentifier or
        not isRawStorageTypeName(expr.receiver.name):
      continue

    if expr.methodName == "release" and expr.methodArguments.len == 1:
      let released = expr.methodArguments[0]
      if released.kind == ekIdentifier:
        var survivors: seq[StaticClaim]
        for claim in claims:
          if claim.variable != released.name:
            survivors.add claim
        claims = survivors
      continue

    if expr.methodName != "reserveAt" or
        expr.methodArguments.len != 3 or variable.len == 0:
      continue
    let backing = expr.methodArguments[0]
    if backing.kind != ekIdentifier:
      continue
    let first = literalNonnegative(expr.methodArguments[1])
    let count = literalNonnegative(expr.methodArguments[2])
    if first < 0 or count <= 0 or count > high(int64) - first:
      continue
    let last = first + count
    for existing in claims:
      if backing.name == existing.region and
          first < existing.last and existing.first < last:
        failAt(expr.span,
          "explicit Storage reservation overlaps prior live allocation '" &
          existing.variable & "' in region '" & backing.name & "'")
    claims.add StaticClaim(
      region: backing.name, variable: variable, first: first, last: last
    )

## Checks provable conflicts in uncomplicated fixed-address programs. Unknown
## addresses, branches and non-Byte layouts remain allocator/programmer-owned.
proc validateStaticStorageReservations*(source: Program) =
  for functionDecl in source.functions:
    checkStraightLineReservations(functionDecl.body)
  for classDecl in source.classes:
    for methodDecl in classDecl.methods:
      checkStraightLineReservations(methodDecl.body)
