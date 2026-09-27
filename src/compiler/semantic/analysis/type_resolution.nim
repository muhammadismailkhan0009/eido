## Converts source type/result syntax into Eido semantic types.
## Example: AST `Int` becomes `etInt`, while omitted `returns` becomes `frNone`.

import ../../diagnostics/errors
import ../../frontend/ast/declarations
import ../../types/model
import ../../types/function_result
import ../symbols/classes

## Converts source built-in type syntax into a semantic Eido type.
## Example: `TypeRef("Float")` resolves to `etFloat` and String resolves to `etString`.
proc resolveType*(typeRef: TypeRef): EidoType =
  case typeRef.name
  of "Bool": etBool
  of "Byte": etByte
  of "Short": etShort
  of "Int": etInt
  of "Float": etFloat
  of "Char": etChar
  of "String": etString
  else:
    failAt(typeRef.span, "unknown built-in type '" & typeRef.name & "'")

## Resolves a field, parameter, or result type from built-ins or registered nominal classes.
## Example: Address resolves to classType("Address") after class-name collection.
proc resolveDeclaredType*(
  typeRef: TypeRef,
  classes: ClassSymbols
): EidoType =
  case typeRef.name
  of "Bool": etBool
  of "Byte": etByte
  of "Short": etShort
  of "Int": etInt
  of "Float": etFloat
  of "Char": etChar
  of "String": etString
  else:
    if classes.contains(typeRef.name):
      return classes.get(typeRef.name).typ
    failAt(typeRef.span, "unknown type '" & typeRef.name & "'")

## Resolves a function's source result declaration.
proc resolveFunctionResult*(
  sourceResult: FunctionResultRef,
  classes: ClassSymbols
): FunctionResult =
  case sourceResult.kind
  of frrNone:
    noResult()
  of frrSingle:
    singleResult(resolveDeclaredType(sourceResult.typeRef, classes))
