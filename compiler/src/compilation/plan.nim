## Carries validated compiler-strategy decisions into backend generation.
## Future strategy outputs should join this object rather than bypassing the pipeline.

import ../compile_time/model

type
  CompilationPlan* = object
    memory*: CompileTimeMemoryPlan
