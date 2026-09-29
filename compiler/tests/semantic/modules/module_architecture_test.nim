import std/[os, strutils, unittest]
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
        - HiddenService.eido
        - ProcessorFactory.eido
      children: []
      dependencies: []
      exports:
        - ProcessorFactory
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "processor" / "HiddenService.eido", """
      class HiddenService implements PaymentService {
        Int stored;
        function value() returns Int { return self.stored; }
      }
    """)
    writeFile(root / "payments" / "processor" / "ProcessorFactory.eido", """
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


  test "stateful class cannot be an explicit export root":
    let root = freshModuleDir("public_class")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: model
      sources:
        - Account.eido
        - Main.eido
      children: []
      dependencies: []
      exports:
        - Account
      provides: {}
      adopts: []
    """)
    writeFile(root / "Account.eido", """
      class Account {
        Int balance;
        function doubled() returns Int { return self.balance * 2; }
      }
    """)
    writeFile(root / "Main.eido", "function main() {}")

    check not checkModule(root).success

  test "exported interface makes class signature types public automatically":
    let root = freshModuleDir("interface_class_closure")
    defer: removeDir(root)
    createDir(root / "payments")
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
        - PaymentRequest.eido
        - PaymentResult.eido
        - PaymentService.eido
      children: []
      dependencies: []
      exports:
        - PaymentService
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "PaymentRequest.eido", """
      class PaymentRequest {
        Int amount;
        function doubled() returns Int { return self.amount * 2; }
      }
    """)
    writeFile(root / "payments" / "PaymentResult.eido", "class PaymentResult { Int code; }")
    writeFile(root / "payments" / "PaymentService.eido", """
      interface PaymentService {
        function pay(PaymentRequest request) returns PaymentResult;
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
        var request = PaymentRequest { amount = 21; };
        return request.doubled();
      }
    """)

    check checkModule(root).success

  test "static export closure is transitive through stateful class surfaces":
    let root = freshModuleDir("transitive_class_closure")
    defer: removeDir(root)
    createDir(root / "api")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        api: { path: api }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - Detail.eido
        - Payload.eido
        - Envelope.eido
        - PublicApi.eido
      children: []
      dependencies: []
      exports:
        - PublicApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Detail.eido", """
      class Detail {
        Int value;
        function read() returns Int { return self.value; }
      }
    """)
    writeFile(root / "api" / "Payload.eido", """
      class Payload {
        Detail detail;
        function createDetail(Int value) returns Detail {
          return Detail { value = value; };
        }
      }
    """)
    writeFile(root / "api" / "Envelope.eido", "class Envelope { Payload payload; }")
    writeFile(root / "api" / "PublicApi.eido", """
      class PublicApi {
        function envelope() returns Envelope {
          return Envelope {
            payload = Payload { detail = Detail { value = 42; }; };
          };
        }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - api
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        var detail = Detail { value = 42; };
        return detail.read();
      }
    """)

    check checkModule(root).success

  test "class not reachable from exported API remains module internal":
    let root = freshModuleDir("private_unreachable_class")
    defer: removeDir(root)
    createDir(root / "api")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        api: { path: api }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - PublicApi.eido
        - InternalThing.eido
      children: []
      dependencies: []
      exports:
        - PublicApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "PublicApi.eido", """
      class PublicApi {
        function value() returns Int { return 1; }
      }
    """)
    writeFile(root / "api" / "InternalThing.eido", "class InternalThing { Int value; }")

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - api
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        var hidden = InternalThing { value = 42; };
        return hidden.value;
      }
    """)

    check not checkModule(root).success

  test "static export exposes returned implementation and its interface through API closure":
    let root = freshModuleDir("implemented_interface_closure")
    defer: removeDir(root)
    createDir(root / "model")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        model: { path: model }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "model" / "module.yaml", """
      module: model
      sources:
        - Readable.eido
        - PublicValue.eido
        - PublicApi.eido
      children: []
      dependencies: []
      exports:
        - PublicApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "model" / "Readable.eido", """
      interface Readable {
        function read() returns Int;
      }
    """)
    writeFile(root / "model" / "PublicValue.eido", """
      class PublicValue implements Readable {
        Int value;
        function read() returns Int { return self.value; }
      }
    """)
    writeFile(root / "model" / "PublicApi.eido", """
      class PublicApi {
        function create() returns PublicValue {
          return PublicValue { value = 42; };
        }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - model
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function readValue(Readable item) returns Int {
        return item.read();
      }

      function main() returns Int {
        return readValue(PublicApi.create());
      }
    """)

    check checkModule(root).success

  test "adopt propagates full transitive class closure to sibling modules":
    let root = freshModuleDir("adopted_class_closure")
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
        - Detail.eido
        - LeftApi.eido
      children: []
      dependencies: []
      exports:
        - LeftApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "left" / "Detail.eido", "class Detail { Int value; }")
    writeFile(root / "left" / "LeftApi.eido", """
      class LeftApi {
        function makeDetail() returns Detail {
          return Detail { value = 42; };
        }
      }
    """)

    writeFile(root / "right" / "module.yaml", """
      module: right
      sources:
        - Right.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "right" / "Right.eido", """
      class Right {
        function value() returns Int {
          var detail = Detail { value = 42; };
          return detail.value;
        }
      }
    """)

    check checkModule(root).success

  test "public API closure follows nested generic type arguments":
    let root = freshModuleDir("generic_api_closure")
    defer: removeDir(root)
    createDir(root / "api")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        api: { path: api }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - Detail.eido
        - Box.eido
        - PublicApi.eido
      children: []
      dependencies: []
      exports:
        - PublicApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Detail.eido", "class Detail { Int value; }")
    writeFile(root / "api" / "Box.eido", "class Box<T> { T value; }")
    writeFile(root / "api" / "PublicApi.eido", """
      class PublicApi {
        function detailBox() returns Box<Detail> {
          return Box<Detail> { value = Detail { value = 42; }; };
        }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - api
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        var detail = Detail { value = 42; };
        return detail.value;
      }
    """)

    check checkModule(root).success

  test "public API re-exposes a reachable dependency class through closure":
    let root = freshModuleDir("dependency_api_reexport")
    defer: removeDir(root)
    createDir(root / "core")
    createDir(root / "api")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        core: { path: core }
        api: { path: api }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "core" / "module.yaml", """
      module: core
      sources:
        - Money.eido
        - InternalPublicCoreType.eido
        - CoreApi.eido
      children: []
      dependencies: []
      exports:
        - CoreApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "core" / "Money.eido", "class Money { Int cents; }")
    writeFile(root / "core" / "InternalPublicCoreType.eido", "class InternalPublicCoreType { Int marker; }")
    writeFile(root / "core" / "CoreApi.eido", """
      class CoreApi {
        function money(Int cents) returns Money {
          return Money { cents = cents; };
        }
        function internal(Int marker) returns InternalPublicCoreType {
          return InternalPublicCoreType { marker = marker; };
        }
      }
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - PaymentRequest.eido
        - PaymentApi.eido
      children: []
      dependencies:
        - core
      exports:
        - PaymentApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "PaymentRequest.eido", "class PaymentRequest { Money amount; }")
    writeFile(root / "api" / "PaymentApi.eido", """
      class PaymentApi {
        function request(Money amount) returns PaymentRequest {
          return PaymentRequest { amount = ref amount; };
        }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - api
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        var money = Money { cents = 42; };
        return money.cents;
      }
    """)

    check checkModule(root).success

  test "dependency APIs not reachable through public closure remain non-transitive":
    let root = freshModuleDir("dependency_api_nontransitive")
    defer: removeDir(root)
    createDir(root / "core")
    createDir(root / "api")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        core: { path: core }
        api: { path: api }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "core" / "module.yaml", """
      module: core
      sources:
        - Money.eido
        - Other.eido
        - CoreApi.eido
      children: []
      dependencies: []
      exports:
        - CoreApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "core" / "Money.eido", "class Money { Int cents; }")
    writeFile(root / "core" / "Other.eido", "class Other { Int value; }")
    writeFile(root / "core" / "CoreApi.eido", """
      class CoreApi {
        function money(Int cents) returns Money {
          return Money { cents = cents; };
        }
        function other(Int value) returns Other {
          return Other { value = value; };
        }
      }
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - PaymentRequest.eido
        - PaymentApi.eido
      children: []
      dependencies:
        - core
      exports:
        - PaymentApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "PaymentRequest.eido", "class PaymentRequest { Money amount; }")
    writeFile(root / "api" / "PaymentApi.eido", """
      class PaymentApi {
        function request(Money amount) returns PaymentRequest {
          return PaymentRequest { amount = ref amount; };
        }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - api
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        var other = Other { value = 42; };
        return other.value;
      }
    """)

    check not checkModule(root).success

  test "duplicate local class names are legal in different modules":
    let root = freshModuleDir("duplicate_local_names")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "users")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        payments: { path: payments }
        users: { path: users }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Result.eido", """
      class Result {
        function value() returns Int { return 42; }
      }
    """)

    writeFile(root / "users" / "module.yaml", """
      module: users
      sources:
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "users" / "Result.eido", """
      class Result {
        function value() returns Int { return 7; }
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
        return Result.value();
      }
    """)

    check checkModule(root).success

  test "unqualified duplicate visible names are ambiguous":
    let root = freshModuleDir("ambiguous_visible_name")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "users")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        payments: { path: payments }
        users: { path: users }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Result.eido", "class Result {}")

    writeFile(root / "users" / "module.yaml", """
      module: users
      sources:
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "users" / "Result.eido", "class Result {}")

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - payments
        - users
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() {
        var outcome = Result {};
      }
    """)

    check not checkModule(root).success

  test "qualified duplicate visible names disambiguate":
    let root = freshModuleDir("qualified_visible_name")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "users")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        payments: { path: payments }
        users: { path: users }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Result.eido", """
      class Result {
        function value() returns Int { return 20; }
      }
    """)

    writeFile(root / "users" / "module.yaml", """
      module: users
      sources:
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "users" / "Result.eido", """
      class Result {
        function value() returns Int { return 22; }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - payments
        - users
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        return payments.Result.value() + users.Result.value();
      }
    """)

    check checkModule(root).success

  test "qualified class path disambiguates static calls":
    let root = freshModuleDir("qualified_static_call")
    defer: removeDir(root)
    createDir(root / "payments")
    createDir(root / "users")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        payments: { path: payments }
        users: { path: users }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "payments" / "module.yaml", """
      module: payments
      sources:
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Factory.eido", """
      class Factory {
        function value() returns Int { return 20; }
      }
    """)

    writeFile(root / "users" / "module.yaml", """
      module: users
      sources:
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    writeFile(root / "users" / "Factory.eido", """
      class Factory {
        function value() returns Int { return 22; }
      }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies:
        - payments
        - users
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function main() returns Int {
        return payments.Factory.value() + users.Factory.value();
      }
    """)

    check checkModule(root).success

  test "same-module nominal shadows same-named dependency API":
    let root = freshModuleDir("local_shadow")
    defer: removeDir(root)
    createDir(root / "payments")
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
        - Result.eido
      children: []
      dependencies: []
      exports:
        - Result
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Result.eido", """
      class Result {
        function remote() returns Int { return 1; }
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
      class Result { Int local; }

      function main() returns Int {
        var outcome = Result { local = 42; };
        return outcome.local;
      }
    """)

    check checkModule(root).success

  test "same top-level function name is legal in different modules":
    let root = freshModuleDir("duplicate_function_names")
    defer: removeDir(root)
    createDir(root / "left")
    createDir(root / "right")
    createDir(root / "app")

    writeFile(root / "module.yaml", """
      module: shop
      sources: []
      children:
        left: { path: left }
        right: { path: right }
        app: { path: app }
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)

    writeFile(root / "left" / "module.yaml", """
      module: left
      sources:
        - Helpers.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "left" / "Helpers.eido", """
      function helper() returns Int { return 1; }
    """)

    writeFile(root / "right" / "module.yaml", """
      module: right
      sources:
        - Helpers.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "right" / "Helpers.eido", """
      function helper() returns Int { return 2; }
    """)

    writeFile(root / "app" / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", "function main() {}")

    check checkModule(root).success

  test "normal module source allows only one outermost nominal declaration":
    let root = freshModuleDir("one_nominal_per_file")
    defer: removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Domain.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(
      root / "Domain.eido",
      "class Account {} interface Repository { function save(); }"
    )

    let result = checkModule(root)
    check not result.success
    check "only one top-level class or interface" in result.diagnostics[0].message

test "module contracts resolve same-module helper functions":
  # Given
  let root = freshModuleDir("contract_helper")
  defer: removeDir(root)
  writeFile(root / "module.yaml", """
    module: shop
    sources:
      - Main.eido
    children: []
    dependencies: []
    exports: []
    provides: {}
    adopts: []
  """)
  writeFile(root / "Main.eido", """
    function valid(Int value) returns Bool {
      return value > 0;
    }

    function checked(Int value) {
      require { valid(value); }
    }

    function main() { checked(1); }
  """)

  # When
  let checked = checkModule(root)

  # Then
  check checked.success


test "module interface contracts resolve self and propagate into provider implementation":
  let root = freshModuleDir("interface_contracts")
  defer: removeDir(root)

  writeFile(root / "module.yaml", """
    module: payments
    sources:
      - PaymentService.eido
      - PaymentImpl.eido
      - Main.eido
    children: []
    dependencies: []
    exports:
      - PaymentService
    provides: {}
    adopts: []
  """)
  writeFile(root / "PaymentService.eido", """
    interface PaymentService {
      function available() returns Int;
      function pay(Int amount) returns Int {
        require { amount > 0; amount <= self.available(); }
        ensure { result >= 0; }
      }
    }
  """)
  writeFile(root / "PaymentImpl.eido", """
    class PaymentImpl implements PaymentService {
      Int balance;
      function available() returns Int { return self.balance; }
      function pay(Int amount) returns Int {
        set self.balance = self.balance - amount;
        return self.balance;
      }
    }
  """)
  writeFile(root / "Main.eido", "function main() {}")

  check checkModule(root).success
