## Defines compilation-policy options independently of any particular memory strategy.
## Memory policy is selected by module identity; an empty identity means no automatic policy.

type
  MemoryPolicySelection* = object
    moduleName*: string

  CompilationOptions* = object
    memoryPolicy*: MemoryPolicySelection

const
  DefaultMemoryPolicyModule* = "eido.stdlib.memory.managed"
  DefaultMemoryPolicy* = MemoryPolicySelection(moduleName: DefaultMemoryPolicyModule)
  NoMemoryPolicy* = MemoryPolicySelection(moduleName: "")
  DefaultCompilationOptions* = CompilationOptions(memoryPolicy: DefaultMemoryPolicy)

## Creates a generic memory-policy selection from one canonical module identity.
proc selectMemoryPolicy*(moduleName: string): MemoryPolicySelection =
  MemoryPolicySelection(moduleName: moduleName)

## Reports whether automatic memory policy is selected for this compilation.
proc isSelected*(selection: MemoryPolicySelection): bool =
  selection.moduleName.len > 0
