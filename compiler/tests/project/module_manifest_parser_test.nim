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

      allowsExternalImplementation:
        - PaymentService

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
    check manifest.allowsExternalImplementation == @["PaymentService"]

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
      allowsExternalImplementation: []
      policySources: []
    """, "module.yaml")

    check manifest.name == "app"
    check manifest.children.len == 0
    check manifest.dependencies.len == 0
    check manifest.exports.len == 0
    check manifest.provides.len == 0
    check manifest.adopts.len == 0
    check manifest.policySources.len == 0
    check manifest.allowsExternalImplementation.len == 0

  test "rejects non-sequence external implementation permissions":
    expect ValueError:
      discard parseModuleManifest("module: app\nallowsExternalImplementation: true", "module.yaml")

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
    check manifest.children.len == 8
    check manifest.children[0].name == "process"
    check manifest.children[1].name == "io"
    check manifest.children[2].name == "storage"
    check manifest.children[3].name == "collections"
    check manifest.children[4].name == "memory"
    check manifest.children[5].name == "text"
    check manifest.children[6].name == "runtime"
    check manifest.children[7].name == "network"
    check manifest.dependencies.len == 0
    check manifest.exports == @[
      "process.Process",
      "io.Console",
      "storage.Storage",
      "storage.Alignment",
      "collections.Array",
      "collections.Arrays",
      "network.NetworkStatus",
      "network.Tcp", "network.TcpConnection", "network.TcpListener"
    ]
    check manifest.provides.len == 0
    check manifest.adopts.len == 0

    let memoryManifest = parseModuleManifest(
      BuiltinMemoryManifestSource,
      BuiltinMemoryManifestPath
    )
    check memoryManifest.name == "memory"
    check memoryManifest.sources.len == 0
    check memoryManifest.children.len == 2
    check memoryManifest.children[0].name == "managed"
    check memoryManifest.children[1].name == "rc"
    check memoryManifest.exports.len == 0

    let managedManifest = parseModuleManifest(
      BuiltinManagedGcManifestSource,
      BuiltinManagedGcManifestPath
    )
    check managedManifest.policySources == @["policy.eido"]

    let rcManifest = parseModuleManifest(
      BuiltinRcManifestSource,
      BuiltinRcManifestPath
    )
    check rcManifest.policySources == @["policy.eido"]

  test "compact nonempty sequences and omitted optional sections":
    let manifest = parseModuleManifest("""
      module: network
      sources: [., "a,b.eido", 'other/']
      dependencies: [storage]
      exports: [Tcp, TcpConnection]
      adopts: [address.SocketAddress]
      allowsExternalImplementation: [TcpConnection]
    """, "module.yaml")
    check manifest.sources == @[".", "a,b.eido", "other/"]
    check manifest.dependencies == @["storage"]
    check manifest.exports == @["Tcp", "TcpConnection"]
    check manifest.adopts == @["address.SocketAddress"]
    check manifest.allowsExternalImplementation == @["TcpConnection"]
    check manifest.children.len == 0
    check manifest.provides.len == 0
    check manifest.policySources.len == 0

  test "rejects malformed inline sequence items":
    for value in ["[a,,b]", "[a, { bad: value }]", "[a, 'unterminated]", "a"]:
      expect ValueError:
        discard parseModuleManifest("module: app\nsources: " & value, "module.yaml")
