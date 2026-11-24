import std/[os, strutils, unittest]
import project/model
import project/modules/loader
import tooling/[documentation_model, documentation_rendering, documentation_service]

## Creates one isolated temporary module project for documentation tests.
proc freshDocumentationProject(name: string): string =
  result = getTempDir() / ("eido_docs_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

## Finds one generated declaration by canonical identity for focused assertions.
proc findDeclaration(
  reference: DocumentationReference,
  canonicalName: string
): DocumentationDeclaration =
  for module in reference.modules:
    for declaration in module.declarations:
      if declaration.canonicalName == canonicalName:
        return declaration
  raise newException(ValueError, "missing documentation declaration: " & canonicalName)

suite "Generated API documentation":
  test "derives public and internal declarations from module API closure":
    let root = freshDocumentationProject("visibility")
    defer:
      if dirExists(root):
        removeDir(root)

    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Factory.eido
        - Order.eido
        - Helper.eido
        - Functions.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    writeFile(root / "Factory.eido", """
      /// Creates public order values.
      class Factory {
          /// Creates one order.
          function create(Int id) returns Order {
              return Order { id = id; };
          }
      }
    """)
    writeFile(root / "Order.eido", """
      /// Order data exposed through Factory.
      class Order {
          /// Stable order identifier.
          Int id;
      }
    """)
    writeFile(root / "Helper.eido", """
      // implementation detail
      class Helper {
          function value() returns Int {
              return 1;
          }
      }
    """)
    writeFile(root / "Functions.eido", """
      function helperValue() returns Int {
          return 1;
      }
    """)

    let project = loadModuleProject(root / "module.yaml", ptLibrary)
    let reference = buildDocumentationReference(project)

    let factory = findDeclaration(reference, "shop.Factory")
    check factory.visibility == dvPublic
    check factory.documentation == "Creates public order values."
    check "shop" in factory.visibleFrom
    check factory.members.len == 1
    check factory.members[0].documentation == "Creates one order."

    let order = findDeclaration(reference, "shop.Order")
    check order.visibility == dvPublic
    check order.documentation == "Order data exposed through Factory."
    check order.members[0].signature == "Int id"

    let helper = findDeclaration(reference, "shop.Helper")
    check helper.visibility == dvInternal
    check helper.documentation.len == 0

  test "includes Storage as an ordinary SDK Eido declaration":
    let root = freshDocumentationProject("storage")
    defer:
      if dirExists(root):
        removeDir(root)

    writeFile(root / "module.yaml", """
      module: empty
      sources:
        - Marker.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Marker.eido", "class Marker {}")

    let reference = buildDocumentationReference(
      loadModuleProject(root / "module.yaml", ptLibrary)
    )

    check reference.compilerProvided.len == 0
    let storage = findDeclaration(reference, "eido.stdlib.storage.Storage")
    check storage.name == "Storage"
    check storage.signature == "class Storage<T>"
    check storage.origin == doSource
    check storage.visibility == dvPublic

    var allocateFound = false
    var sizeFound = false
    for member in storage.members:
      if member.name == "allocate":
        allocateFound = true
        check not member.isNative
      if member.name == "size":
        sizeFound = true
        check member.isNative
    check allocateFound
    check sizeFound

    let html = renderDocumentationHtml(reference)
    let json = renderDocumentationJson(reference)
    check "eido.stdlib.storage" in html
    check "Storage&lt;T&gt;" in html
    check "\"origin\": \"Source\"" in json
