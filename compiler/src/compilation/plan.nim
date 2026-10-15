## Carries validated compiler metadata into backend generation.
## Memory-management policy remains outside this model in the selected Eido runtime.

import ../compile_time/[instrumentation_model, model]

type
  CompilationPlan* = object
    memory*: CompileTimeMemoryMetadata
    instrumentation*: CompileTimeInstrumentationPlan
