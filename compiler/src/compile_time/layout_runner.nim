## Converts source-backed layout declarations into build-machine Eido methods.
## Runs each named definition before the compiler selects one active layout.

import ../hir/program as hirProgram

## Compiles user layout bodies into a private Eido module of static methods.
## The layout declarations are evaluated on the build machine, never at runtime.
proc layoutRunnerSource*(
  program: hirProgram.HirProgram
): tuple[layoutSource: string, runnerSource: string] =
  result.layoutSource = "class UserLayoutRunners {\n"
  result.runnerSource = "function main() {\n    MemoryMetadataBuilder.build();\n"
  for index, declaration in program.layouts:
    result.layoutSource.add(
      "    function run" & $index & "() returns Layout {\n" &
      declaration.bodySource & "\n    }\n"
    )
    # Eido's standard native String bridge transports the class name.
    result.runnerSource.add(
      "    LayoutRuntime.begin(" & $index & ", \"" &
      declaration.targetClass & "\");\n" &
      "    var shape" & $index & " = UserLayoutRunners.run" & $index & "();\n" &
      "    shape" & $index & ".submit();\n"
    )
  result.layoutSource.add "}\n"
  result.runnerSource.add "}\n"
