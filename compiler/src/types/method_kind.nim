## Defines whether a class-owned function requires an instance receiver.
## Eido infers this from explicit self dependency rather than a source-level static keyword.

type
  MethodKind* = enum
    mkInstance,
    mkStatic
