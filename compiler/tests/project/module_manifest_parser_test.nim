import std/unittest
import project/modules/manifest_parser
import stdlib/builtin_sources

suite "Module manifest parsing":
  test "parses the complete v0 YAML module schema":
    let manifest = parseModuleManifest("""
      module: payments

      sources:
        - PaymentService.eido
        - Payments.eido

      children:
        processor:
          path: processor
        risk:
          path: subsystems/risk

      dependencies:
        - database
        - logging

      exports:
        - Payments
        - processor.ProcessorHealth

      provides:
        PaymentProcessor:
          by: processor

      adopts:
        - processor.ProcessorHealth

      policySources:
        - policy.eido
    """, "payments/module.yaml")

    check manifest.name == "payments"
    check manifest.sources == @["PaymentService.eido", "Payments.eido"]
    check manifest.children.len == 2
    check manifest.children[0].name == "processor"
    check manifest.children[0].path == "processor"
    check manifest.children[1].name == "risk"
    check manifest.children[1].path == "subsystems/risk"
    check manifest.dependencies == @["database", "logging"]
    check manifest.exports == @["Payments", "processor.ProcessorHealth"]
    check manifest.provides.len == 1
    check manifest.provides[0].contract == "PaymentProcessor"
    check manifest.provides[0].by == "processor"
    check manifest.adopts == @["processor.ProcessorHealth"]
    check manifest.policySources == @["policy.eido"]

  test "accepts empty YAML sequences":
    let manifest = parseModuleManifest("""
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
      policySources: []
    """, "module.yaml")

    check manifest.name == "app"
    check manifest.children.len == 0
    check manifest.dependencies.len == 0
    check manifest.exports.len == 0
    check manifest.provides.len == 0
    check manifest.adopts.len == 0
    check manifest.policySources.len == 0

  test "rejects unknown top-level keys":
    expect ValueError:
      discard parseModuleManifest("""
        module: app
        sources:
          - Main.eido
        magic: true
      """, "module.yaml")

  test "parses the embedded standard library manifest through the normal schema":
    let manifest = parseModuleManifest(
      BuiltinStdlibManifestSource,
      BuiltinStdlibManifestPath
    )

    check manifest.name == "stdlib"
    check manifest.sources.len == 0
    check manifest.children.len == 5
    check manifest.children[0].name == "process"
    check manifest.children[1].name == "io"
    check manifest.children[2].name == "memory"
    check manifest.children[3].name == "text"
    check manifest.children[4].name == "runtime"
    check manifest.dependencies.len == 0
    check manifest.exports == @[
      "process.Process",
      "io.Console"
    ]
    check manifest.provides.len == 0
    check manifest.adopts.len == 0

    let memoryManifest = parseModuleManifest(
      BuiltinMemoryManifestSource,
      BuiltinMemoryManifestPath
    )
    check memoryManifest.name == "memory"
    check memoryManifest.sources.len == 0
    check memoryManifest.children.len == 1
    check memoryManifest.children[0].name == "managed"
    check memoryManifest.exports.len == 0

    let managedManifest = parseModuleManifest(
      BuiltinManagedGcManifestSource,
      BuiltinManagedGcManifestPath
    )
    check managedManifest.policySources == @["policy.eido"]
