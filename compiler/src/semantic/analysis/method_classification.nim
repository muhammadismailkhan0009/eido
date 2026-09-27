## Infers whether Eido-bodied class functions are instance or static from explicit self dependency.
## Bodyless native class functions bypass inference and are resolved as static at signature collection.

import ../../frontend/ast/[declarations, expressions, statements]
import ../../types/method_kind

## Reports whether an expression directly or recursively depends on self.
## Example: `self.balance + amount` is self-dependent while `left + right` is not.
proc expressionUsesSelf(expr: Expr): bool =
  if expr.isNil:
    return false

  case expr.kind
  of ekIdentifier:
    expr.name == "self"
  of ekCall:
    for argument in expr.arguments:
      if expressionUsesSelf(argument):
        return true
    false
  of ekConstruct:
    for field in expr.fields:
      if expressionUsesSelf(field.value):
        return true
    false
  of ekClassRelation:
    expressionUsesSelf(expr.relatedValue)
  of ekFieldAccess:
    expressionUsesSelf(expr.target)
  of ekMethodCall:
    if expressionUsesSelf(expr.receiver):
      return true
    for argument in expr.methodArguments:
      if expressionUsesSelf(argument):
        return true
    false
  of ekUnary:
    expressionUsesSelf(expr.operand)
  of ekBinary:
    expressionUsesSelf(expr.left) or expressionUsesSelf(expr.right)
  of ekInteger, ekFloat, ekBoolean, ekChar, ekString:
    false

## Reports whether a statement or any nested statement depends on self.
## Example: an if condition or branch containing `self.field` makes the owning method instance-bound.
proc statementUsesSelf(stmt: Stmt): bool

## Reports whether any statement in a block depends on self.
## Example: one self-dependent nested statement is enough to classify the whole method as instance-bound.
proc blockUsesSelf(statements: seq[Stmt]): bool =
  for statement in statements:
    if statementUsesSelf(statement):
      return true
  false

## Reports whether one statement depends on self.
## Example: local initialization from `self.value()` returns true.
proc statementUsesSelf(stmt: Stmt): bool =
  case stmt.kind
  of skVar:
    expressionUsesSelf(stmt.initializer)
  of skAssign:
    expressionUsesSelf(stmt.target) or expressionUsesSelf(stmt.assignedValue)
  of skCall:
    expressionUsesSelf(stmt.call)
  of skReturn:
    expressionUsesSelf(stmt.value)
  of skIf:
    expressionUsesSelf(stmt.condition) or
      blockUsesSelf(stmt.thenBranch) or
      blockUsesSelf(stmt.elseBranch)
  of skWhile:
    expressionUsesSelf(stmt.whileCondition) or blockUsesSelf(stmt.body)
  of skFor:
    statementUsesSelf(stmt.forInitializer) or
      expressionUsesSelf(stmt.forCondition) or
      statementUsesSelf(stmt.forUpdate) or
      blockUsesSelf(stmt.forBody)
  of skBreak, skContinue:
    false

## Infers the class-method kind from explicit self reachability.
## Example: `Money.fromCents` is static when its body never reaches self.
proc inferMethodKind*(sourceMethod: FunctionDecl): MethodKind =
  if blockUsesSelf(sourceMethod.body):
    mkInstance
  else:
    mkStatic
