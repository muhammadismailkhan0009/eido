## Defines source-file identity and text shared by project compilation and tooling.
## Example: SourceUnit 2 may identify `src/account.eido` and carry its complete source text.

type
  SourceId* = distinct int

  SourceUnit* = object
    id*: SourceId
    path*: string
    text*: string
    moduleName*: string

## Creates one source unit with stable project-local identity.
## Module-aware projects also attach the owning canonical module name.
proc initSourceUnit*(
  id: int,
  path, text: string,
  moduleName: string = ""
): SourceUnit =
  SourceUnit(
    id: SourceId(id),
    path: path,
    text: text,
    moduleName: moduleName
  )

## Extracts the integer value of a source identity.
## Example: SourceId(3) has value 3.
proc value*(id: SourceId): int = int(id)
