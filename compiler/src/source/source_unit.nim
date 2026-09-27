## Defines source-file identity and text shared by project compilation and tooling.
## Example: SourceUnit 2 may identify `src/account.eido` and carry its complete source text.

type
  SourceId* = distinct int

  SourceUnit* = object
    id*: SourceId
    path*: string
    text*: string

## Creates one source unit with stable project-local identity.
## Example: `initSourceUnit(0, "src/main.eido", source)` creates the first project source.
proc initSourceUnit*(id: int, path, text: string): SourceUnit =
  SourceUnit(id: SourceId(id), path: path, text: text)

## Extracts the integer value of a source identity.
## Example: SourceId(3) has value 3.
proc value*(id: SourceId): int = int(id)
