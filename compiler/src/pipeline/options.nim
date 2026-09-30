## Defines compilation-policy options that are independent of source/module architecture.
## Example: the same Eido project may compile with GC planning or explicit manual memory.

type
  MemoryStrategy* = enum
    msGc,
    msManual

  CompilationOptions* = object
    memoryStrategy*: MemoryStrategy

const
  DefaultCompilationOptions* = CompilationOptions(memoryStrategy: msGc)

## Parses the stable CLI spelling of one compiler memory strategy.
## Example: gc selects the current precise mark-and-sweep strategy.
proc parseMemoryStrategy*(name: string): MemoryStrategy =
  case name
  of "gc":
    msGc
  of "manual":
    msManual
  else:
    raise newException(
      ValueError,
      "unknown Eido memory strategy '" & name &
        "'; expected gc or manual"
    )

## Returns the stable CLI spelling of one compiler memory strategy.
## Example: msManual renders as manual.
proc memoryStrategyName*(strategy: MemoryStrategy): string =
  case strategy
  of msGc: "gc"
  of msManual: "manual"
