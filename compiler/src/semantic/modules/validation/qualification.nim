## Rewrites module-project source references to canonical semantic identities.
## Focused fragments keep name resolution, expressions, statements, and declarations separate.

include ../qualification/resolution

## Declares recursive expression qualification before statement qualification.
proc qualifyExpr(
  source: Expr,
  currentModule: string,
  locals: HashSet[string],
  typeParameters: HashSet[string],
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  rootModule: string
)

## Declares recursive statement qualification before expression qualification.
proc qualifyStatements(
  statements: seq[Stmt],
  currentModule: string,
  initialLocals: HashSet[string],
  typeParameters: HashSet[string],
  modules: ModuleRegistry,
  classes: ClassRegistry,
  interfaces: InterfaceRegistry,
  functions: FunctionOwnerRegistry,
  publicSurfaces, adoptedSurfaces, providedSurfaces: SurfaceRegistry,
  rootModule: string
)

include ../qualification/expressions
include ../qualification/statements
include ../qualification/declarations
