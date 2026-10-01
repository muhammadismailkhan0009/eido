## Renders generated Eido API documentation as static HTML and machine-readable JSON.

import std/[json, strutils]
import documentation_model

## Converts documentation visibility into a reader-facing label.
proc visibilityText(visibility: DocumentationVisibility): string =
  case visibility
  of dvPublic: "Public API"
  of dvInternal: "Module-internal"

## Converts declaration origin into a reader-facing label.
proc originText(origin: DocumentationOrigin): string =
  case origin
  of doSource: "Source"
  of doCompiler: "Compiler-provided"

## Converts a declaration kind into a reader-facing label.
proc declarationKindText(kind: DocumentationDeclarationKind): string =
  case kind
  of ddkClass: "Class"
  of ddkInterface: "Interface"
  of ddkFunction: "Function"

## Describes one member kind including static ownership.
proc memberKindText(member: DocumentationMember): string =
  case member.kind
  of dmkField:
    if member.isStatic: "Class field" else: "Field"
  of dmkMethod:
    if member.isStatic: "Static method" else: "Instance method"

## Escapes plain documentation text for safe HTML rendering.
proc htmlEscape(value: string): string =
  result = value
  result = result.replace("&", "&amp;")
  result = result.replace("<", "&lt;")
  result = result.replace(">", "&gt;")
  result = result.replace("\"", "&quot;")
  result = result.replace("'", "&#39;")

## Converts a declaration identity into a stable HTML anchor fragment.
proc anchorId(value: string): string =
  for character in value:
    if character.isAlphaNumeric:
      result.add character.toLowerAscii
    else:
      result.add '-'

## Renders documentation prose or an explicit undocumented marker.
proc renderDocumentationText(value: string): string =
  if value.len == 0:
    return "<span class=\"undocumented\">No /// documentation comment.</span>"
  htmlEscape(value).replace("\n", "<br>")

## Renders visibility, origin, and declaration-kind badges.
proc renderBadges(declaration: DocumentationDeclaration): string =
  result.add "<div class=\"badges\">"
  result.add "<span class=\"badge " &
    (if declaration.visibility == dvPublic: "public" else: "internal") &
    "\">" & visibilityText(declaration.visibility) & "</span>"
  result.add "<span class=\"badge\">" & originText(declaration.origin) & "</span>"
  result.add "<span class=\"badge\">" & declarationKindText(declaration.kind) & "</span>"
  result.add "</div>"

## Renders one documented declaration member as HTML.
proc renderMember(member: DocumentationMember): string =
  result.add "<div class=\"member\">"
  result.add "<div class=\"member-head\"><code>" &
    htmlEscape(member.signature) & "</code><div class=\"badges\">"
  result.add "<span class=\"badge\">" & memberKindText(member) & "</span>"
  if member.isNative:
    result.add "<span class=\"badge\">native boundary</span>"
  if member.availability.len > 0:
    result.add "<span class=\"badge availability\">" &
      htmlEscape(member.availability) & "</span>"
  result.add "</div></div>"
  result.add "<p>" & renderDocumentationText(member.documentation) & "</p>"
  result.add "</div>"

## Renders one complete declaration card as HTML.
proc renderDeclaration(declaration: DocumentationDeclaration): string =
  let id = anchorId(declaration.canonicalName)
  result.add "<article class=\"declaration\" id=\"" & id & "\">"
  result.add renderBadges(declaration)
  result.add "<h3>" & htmlEscape(declaration.name) & "</h3>"
  result.add "<pre><code>" & htmlEscape(declaration.signature) & "</code></pre>"
  result.add "<p>" & renderDocumentationText(declaration.documentation) & "</p>"

  if declaration.visibleFrom.len > 0:
    result.add "<p class=\"meta\"><strong>Visible from:</strong> " &
      htmlEscape(declaration.visibleFrom.join(", ")) & "</p>"
  if declaration.sourcePath.len > 0:
    result.add "<p class=\"meta\"><strong>Source:</strong> " &
      htmlEscape(declaration.sourcePath) & "</p>"

  if declaration.members.len > 0:
    result.add "<h4>Members</h4>"
    for member in declaration.members:
      result.add renderMember(member)

  result.add "</article>"

## Renders public and internal declaration groups for one module.
proc renderModule(module: DocumentationModule): string =
  let id = anchorId("module-" & module.name)
  result.add "<section class=\"module\" id=\"" & id & "\">"
  result.add "<div class=\"module-title\"><h2>" & htmlEscape(module.name) & "</h2>"
  if module.isSdk:
    result.add "<span class=\"badge\">SDK</span>"
  result.add "</div>"

  var publicCount = 0
  var internalCount = 0
  for declaration in module.declarations:
    if declaration.visibility == dvPublic:
      inc publicCount
    else:
      inc internalCount

  result.add "<p class=\"meta\">" & $publicCount & " public, " &
    $internalCount & " module-internal declarations.</p>"

  if publicCount > 0:
    result.add "<h3 class=\"group-heading\">Public API</h3>"
    for declaration in module.declarations:
      if declaration.visibility == dvPublic:
        result.add renderDeclaration(declaration)

  if internalCount > 0:
    result.add "<details class=\"internal-group\"><summary>Module-internal declarations (" &
      $internalCount & ")</summary>"
    for declaration in module.declarations:
      if declaration.visibility == dvInternal:
        result.add renderDeclaration(declaration)
    result.add "</details>"

  if module.declarations.len == 0:
    result.add "<p class=\"meta\">This module declares no source types or functions directly.</p>"

  result.add "</section>"

## Renders one self-contained browsable API reference.
proc renderDocumentationHtml*(reference: DocumentationReference): string =
  result.add """<!doctype html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Eido API Reference</title>
<style>
:root { color-scheme: light dark; font-family: Inter, ui-sans-serif, system-ui, sans-serif; }
* { box-sizing: border-box; }
body { margin: 0; line-height: 1.55; }
a { color: inherit; }
.layout { display: grid; grid-template-columns: 280px minmax(0, 1fr); min-height: 100vh; }
aside { border-right: 1px solid #7775; padding: 24px; position: sticky; top: 0; height: 100vh; overflow: auto; }
main { max-width: 1100px; width: 100%; padding: 42px 48px 100px; }
nav a { display: block; padding: 5px 0; text-decoration: none; opacity: .82; }
nav a:hover { opacity: 1; text-decoration: underline; }
.legend, .notice { border: 1px solid #7775; border-radius: 12px; padding: 16px 18px; margin: 18px 0 28px; }
.module { padding-top: 24px; margin-top: 36px; border-top: 1px solid #7775; }
.module-title { display: flex; align-items: center; gap: 12px; }
.declaration { border: 1px solid #7775; border-radius: 14px; padding: 20px; margin: 16px 0; }
.member { border-top: 1px solid #7774; padding: 14px 0 4px; }
.member-head { display: flex; justify-content: space-between; gap: 14px; align-items: flex-start; flex-wrap: wrap; }
.badges { display: flex; gap: 7px; flex-wrap: wrap; }
.badge { border: 1px solid #7776; border-radius: 999px; padding: 2px 8px; font-size: .78rem; white-space: nowrap; }
.badge.public { font-weight: 700; }
.badge.internal { opacity: .7; }
.badge.availability { font-style: italic; }
pre { overflow-x: auto; padding: 12px 14px; border-radius: 8px; background: #7771; }
code { font-family: ui-monospace, SFMono-Regular, Menlo, monospace; }
.meta { opacity: .72; font-size: .9rem; }
.undocumented { opacity: .58; font-style: italic; }
.internal-group { margin-top: 22px; }
.internal-group > summary { cursor: pointer; font-weight: 700; padding: 10px 0; }
.group-heading { margin-top: 24px; }
@media (max-width: 800px) {
  .layout { display: block; }
  aside { position: static; height: auto; border-right: 0; border-bottom: 1px solid #7775; }
  main { padding: 28px 20px 70px; }
}
</style>
</head>
<body>
<div class="layout">
<aside>
<h2>Eido API</h2>
<p class="meta">""" & htmlEscape(reference.projectName) & """</p>
<nav>
<a href="#overview">Overview</a>
<a href="#compiler-provided">Compiler-provided API</a>
"""
  for module in reference.modules:
    result.add "<a href=\"#" & anchorId("module-" & module.name) & "\">" &
      htmlEscape(module.name) & "</a>\n"

  result.add """</nav>
</aside>
<main>
<section id="overview">
<h1>Eido API Reference</h1>
<p>Generated from module manifests, compiler visibility rules, and <code>///</code> documentation comments.</p>
<div class="legend">
<strong>How to read this reference</strong>
<p><span class="badge public">Public API</span> is reachable through Eido's module API closure and may be used by consumers that can see that module.</p>
<p><span class="badge internal">Module-internal</span> is real Eido source but is not exposed through a public module surface.</p>
<p><span class="badge">Compiler-provided</span> is public Eido surface synthesized by the toolchain rather than declared in an <code>.eido</code> source file.</p>
</div>
<div class="notice">
<strong>Not Eido API:</strong> backend support files, generated Nim symbols, GC bridge procedures, compiler implementation helpers, and other implementation machinery are intentionally excluded. Their existence does not make them callable Eido API.
</div>
</section>
<section id="compiler-provided">
<h2>Compiler-provided API</h2>
"""
  for declaration in reference.compilerProvided:
    result.add renderDeclaration(declaration)
  result.add "</section>"

  for module in reference.modules:
    result.add renderModule(module)

  result.add """
</main>
</div>
</body>
</html>
"""

## Converts one documented member into the stable JSON representation.
proc memberJson(member: DocumentationMember): JsonNode =
  result = newJObject()
  result["name"] = %member.name
  result["signature"] = %member.signature
  result["documentation"] = %member.documentation
  result["kind"] = %memberKindText(member)
  result["static"] = %member.isStatic
  result["native"] = %member.isNative
  result["availability"] = %member.availability

## Converts one documented declaration into the stable JSON representation.
proc declarationJson(declaration: DocumentationDeclaration): JsonNode =
  result = newJObject()
  result["name"] = %declaration.name
  result["canonicalName"] = %declaration.canonicalName
  result["module"] = %declaration.moduleName
  result["source"] = %declaration.sourcePath
  result["signature"] = %declaration.signature
  result["documentation"] = %declaration.documentation
  result["kind"] = %declarationKindText(declaration.kind)
  result["visibility"] = %visibilityText(declaration.visibility)
  result["origin"] = %originText(declaration.origin)

  let visible = newJArray()
  for moduleName in declaration.visibleFrom:
    visible.add %moduleName
  result["visibleFrom"] = visible

  let members = newJArray()
  for member in declaration.members:
    members.add memberJson(member)
  result["members"] = members

## Renders the same reference model as stable machine-readable JSON.
proc renderDocumentationJson*(reference: DocumentationReference): string =
  let root = newJObject()
  root["project"] = %reference.projectName

  let compilerProvided = newJArray()
  for declaration in reference.compilerProvided:
    compilerProvided.add declarationJson(declaration)
  root["compilerProvided"] = compilerProvided

  let modules = newJArray()
  for module in reference.modules:
    let moduleNode = newJObject()
    moduleNode["name"] = %module.name
    moduleNode["sdk"] = %module.isSdk

    let declarations = newJArray()
    for declaration in module.declarations:
      declarations.add declarationJson(declaration)
    moduleNode["declarations"] = declarations
    modules.add moduleNode

  root["modules"] = modules
  pretty(root)
