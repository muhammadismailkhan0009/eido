## Generates static API reference artifacts for Eido module projects and the SDK.

import std/os
import ../../../../compiler/src/project/model
import ../../../../compiler/src/project/modules/loader
import ../../../../compiler/src/stdlib/builtin_sources
import ../../../../compiler/src/tooling/[
  documentation_rendering,
  documentation_service
]

## Writes the generated HTML and JSON reference for one analyzed project.
proc writeDocumentation(project: EidoProject, outputDirectory: string) =
  let reference = buildDocumentationReference(project)

  createDir(outputDirectory)
  writeFile(
    outputDirectory / "index.html",
    renderDocumentationHtml(reference)
  )
  writeFile(
    outputDirectory / "api.json",
    renderDocumentationJson(reference)
  )

## Builds HTML and JSON API documentation for one module project.
proc generateModuleDocumentation*(
  manifestPath: string,
  outputDirectory: string
) =
  writeDocumentation(
    loadModuleProject(manifestPath, ptLibrary),
    outputDirectory
  )

## Builds HTML and JSON API documentation for the embedded Eido standard library.
proc generateStdlibDocumentation*(outputDirectory: string) =
  writeDocumentation(
    builtinStdlibProject(),
    outputDirectory
  )
