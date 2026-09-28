import std/[os, unittest]
import project/model
import project/modules/loader
import tooling/compiler_service

## Documents the freshModuleDir module helper behavior.
proc freshModuleDir(name: string): string =
  result = getTempDir() / ("eido_arch_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

## Documents the checkModule module helper behavior.
proc checkModule(root: string): ProjectCheckResult =
  checkProject(loadModuleProject(root / "module.yaml", ptExecutable))

suite "Module architecture":
  test "direct dependency may call an exported static class":
    let root = freshModuleDir("public_static")
    defer: removeDir(root)
    createDir(root / "logging")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        logging: { path: logging }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "logging" / "module.yaml", """
      module: logging
      sources:
        - Logging.eido
      children: []
      dependencies: []
      exports:
        - Logging
      provides: {}
      adopts: []
    """)
    writeFile(root / "logging" / "Logging.eido", """
      class Logging {
        function write(String value) {}
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - App.eido
      children: []
      dependencies:
        - logging
      exports:
        - App
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "App.eido", """
      class App {
        function run() {
          Logging.write("ok");
        }
      }
    """)

    check checkModule(root).success

  test "unexported dependency implementation is invisible":
    let root = freshModuleDir("private_dep")
    defer: removeDir(root)
    createDir(root / "logging")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        logging: { path: logging }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "logging" / "module.yaml", """
      module: logging
      sources:
        - Secret.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "logging" / "Secret.eido", """
      class Secret {
        function touch() {}
      }
    """)
    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - App.eido
      children: []
      dependencies:
        - logging
      exports:
        - App
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "App.eido", """
      class App {
        function run() { Secret.touch(); }
      }
    """)

    check not checkModule(root).success

  test "rejects exporting a concrete instance class":
    let root = freshModuleDir("instance_export")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
        - Stateful.eido
      children: []
      dependencies: []
      exports:
        - Stateful
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")
    writeFile(root / "Stateful.eido", """
      class Stateful {
        Int count;
        function read() returns Int { return self.count; }
      }
    """)

    check not checkModule(root).success

  test "parent dependencies propagate downward to children":
    let root = freshModuleDir("dep_propagation")
    defer: removeDir(root)
    createDir(root / "logging")
    createDir(root / "payments")
    createDir(root / "payments" / "processor")

    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        logging: { path: logging }
        payments: { path: payments }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "logging" / "module.yaml", """
      module: logging
      sources:
        - Logging.eido
      children: []
      dependencies: []
      exports:
        - Logging
      provides: {}
      adopts: []
    """)
    writeFile(root / "logging" / "Logging.eido", """
      class Logging { function write(String value) {} }
    """)

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - Payments.eido
      children:
        processor: { path: processor }
      dependencies:
        - logging
      exports:
        - Payments
      provides: {}
      adopts:
        - processor.Processor
    """)
    writeFile(root / "payments" / "Payments.eido", """
      class Payments { function run() { Processor.run(); } }
    """)

    writeFile(root / "payments" / "processor" / "module.yaml", """
      module: processor
      sources:
        - Processor.eido
      children: []
      dependencies: []
      exports:
        - Processor
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "processor" / "Processor.eido", """
      class Processor {
        function run() { Logging.write("processor"); }
      }
    """)

    check checkModule(root).success

  test "child export reaches sibling only after explicit parent adoption":
    let root = freshModuleDir("adoption")
    defer: removeDir(root)
    createDir(root / "left")
    createDir(root / "right")

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children:
        left: { path: left }
        right: { path: right }
      dependencies: []
      exports: []
      provides: {}
      adopts:
        - left.LeftApi
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "left" / "module.yaml", """
      module: left
      sources:
        - LeftApi.eido
      children: []
      dependencies: []
      exports:
        - LeftApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "left" / "LeftApi.eido", """
      class LeftApi { function value() returns Int { return 42; } }
    """)

    writeFile(root / "right" / "module.yaml", """
      module: right
      sources:
        - RightApi.eido
      children: []
      dependencies: []
      exports:
        - RightApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "right" / "RightApi.eido", """
      class RightApi {
        function run() returns Int { return LeftApi.value(); }
      }
    """)

    check checkModule(root).success

  test "child export does not propagate upward or sideways without adoption":
    let root = freshModuleDir("no_adoption")
    defer: removeDir(root)
    createDir(root / "left")
    createDir(root / "right")

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children:
        left: { path: left }
        right: { path: right }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "left" / "module.yaml", """
      module: left
      sources:
        - LeftApi.eido
      children: []
      dependencies: []
      exports:
        - LeftApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "left" / "LeftApi.eido", """
      class LeftApi { function value() returns Int { return 42; } }
    """)

    writeFile(root / "right" / "module.yaml", """
      module: right
      sources:
        - RightApi.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "right" / "RightApi.eido", """
      class RightApi {
        function run() returns Int { return LeftApi.value(); }
      }
    """)

    check not checkModule(root).success

  test "parent may explicitly re-export a child static API":
    let root = freshModuleDir("child_reexport")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "payments" / "facade")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        payments: { path: payments }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources: []
      children:
        facade: { path: facade }
      dependencies: []
      exports:
        - facade.ChildApi
      provides: {}
      adopts: []
    """)

    writeFile(root / "payments" / "facade" / "module.yaml", """
      module: facade
      sources:
        - ChildApi.eido
      children: []
      dependencies: []
      exports:
        - ChildApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "facade" / "ChildApi.eido", """
      class ChildApi { function value() returns Int { return 42; } }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - App.eido
      children: []
      dependencies:
        - payments
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "App.eido", """
      class App {
        function run() returns Int { return ChildApi.value(); }
      }
    """)

    check checkModule(root).success

  test "parent-owned interface is implemented by declared child provider":
    let root = freshModuleDir("interface_provider")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "payments" / "processor")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        payments: { path: payments }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - PaymentService.eido
        - Payments.eido
      children:
        processor: { path: processor }
      dependencies: []
      exports:
        - PaymentService
        - Payments
      provides:
        PaymentService:
          by: processor
      adopts:
        - processor.ProcessorFactory
    """)
    writeFile(root / "payments" / "PaymentService.eido", """
      interface PaymentService {
        function value() returns Int;
      }
    """)
    writeFile(root / "payments" / "Payments.eido", """
      class Payments {
        function service() returns PaymentService {
          return ProcessorFactory.create();
        }
      }
    """)

    writeFile(root / "payments" / "processor" / "module.yaml", """
      module: processor
      sources:
        - Processor.eido
      children: []
      dependencies: []
      exports:
        - ProcessorFactory
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "processor" / "Processor.eido", """
      class HiddenService implements PaymentService {
        Int stored;

        function value() returns Int {
          return self.stored;
        }
      }

      class ProcessorFactory {
        function create() returns PaymentService {
          return HiddenService { stored = 42; };
        }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - payments
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        var service = Payments.service();
        return service.value();
      }
    """)

    check checkModule(root).success

  test "unrelated module cannot implement a closed interface":
    let root = freshModuleDir("closed_interface")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "plugin")

    writeFile(root / "module.yaml", """
      module: shop
      sources:
        - Main.eido
      children:
        payments: { path: payments }
        plugin: { path: plugin }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - PaymentService.eido
      children: []
      dependencies: []
      exports:
        - PaymentService
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "PaymentService.eido", """
      interface PaymentService {
        function value() returns Int;
      }
    """)

    writeFile(root / "plugin" / "module.yaml", """
      module: plugin
      sources:
        - Fake.eido
      children: []
      dependencies:
        - payments
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "plugin" / "Fake.eido", """
      class Fake implements PaymentService {
        function value() returns Int {
          return 1;
        }
      }
    """)

    check not checkModule(root).success

  test "provides requires an implementation in the declared provider subtree":
    let root = freshModuleDir("missing_provider")
    defer: removeDir(root)
    createDir(root / "processor")

    writeFile(root / "module.yaml", """
      module: payments
      sources:
        - PaymentService.eido
        - Main.eido
      children:
        processor: { path: processor }
      dependencies: []
      exports: []
      provides:
        PaymentService:
          by: processor
      adopts: []
    """)
    writeFile(root / "PaymentService.eido", """
      interface PaymentService {
        function value() returns Int;
      }
    """)
    writeFile(root / "Main.eido", "function main() {}")

    writeFile(root / "processor" / "module.yaml", """
      module: processor
      sources:
        - Empty.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "processor" / "Empty.eido", "class Empty {}")

    check not checkModule(root).success
