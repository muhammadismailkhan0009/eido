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

  test "allows exporting a concrete instance class":
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

    check checkModule(root).success

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


  test "stateful class may be exported directly with its complete surface":
    let root = freshModuleDir("public_class")
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
        - Account.eido
      children: []
      dependencies: []
      exports:
        - Account
      provides: {}
      adopts: []
    """)
    writeFile(root / "model" / "Account.eido", """
      class Account {
        Int balance;

        function doubled() returns Int {
          return self.balance * 2;
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
      function main() returns Int {
        var account = Account { balance = 21; };
        return account.doubled();
      }
    """)

    check checkModule(root).success

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
        - Api.eido
      children: []
      dependencies: []
      exports:
        - PaymentService
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Api.eido", """
      class PaymentRequest {
        Int amount;

        function doubled() returns Int {
          return self.amount * 2;
        }
      }

      class PaymentResult {
        Int code;
      }

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

  test "public class closure is transitive through fields and method signatures":
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
        - Models.eido
      children: []
      dependencies: []
      exports:
        - Envelope
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Models.eido", """
      class Detail {
        Int value;

        function read() returns Int {
          return self.value;
        }
      }

      class Payload {
        Detail detail;

        function createDetail(Int value) returns Detail {
          return Detail { value = value; };
        }
      }

      class Envelope {
        Payload payload;
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
        - Api.eido
      children: []
      dependencies: []
      exports:
        - PublicApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Api.eido", """
      class PublicApi {
        function value() returns Int {
          return 1;
        }
      }

      class InternalThing {
        Int value;
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
        var hidden = InternalThing { value = 42; };
        return hidden.value;
      }
    """)

    check not checkModule(root).success


  test "exported class exposes its implemented interface through API closure":
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
        - Model.eido
      children: []
      dependencies: []
      exports:
        - PublicValue
      provides: {}
      adopts: []
    """)
    writeFile(root / "model" / "Model.eido", """
      interface Readable {
        function read() returns Int;
      }

      class PublicValue implements Readable {
        Int value;

        function read() returns Int {
          return self.value;
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
        return readValue(PublicValue { value = 42; });
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
        - Left.eido
      children: []
      dependencies: []
      exports:
        - LeftApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "left" / "Left.eido", """
      class Detail {
        Int value;
      }

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
        - Api.eido
      children: []
      dependencies: []
      exports:
        - PublicApi
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Api.eido", """
      class Detail {
        Int value;
      }

      class Box<T> {
        T value;
      }

      class PublicApi {
        function detailBox() returns Box<Detail> {
          return Box<Detail> {
            value = Detail { value = 42; };
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
        - Core.eido
      children: []
      dependencies: []
      exports:
        - Money
        - InternalPublicCoreType
      provides: {}
      adopts: []
    """)
    writeFile(root / "core" / "Core.eido", """
      class Money {
        Int cents;
      }

      class InternalPublicCoreType {
        Int marker;
      }
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - Api.eido
      children: []
      dependencies:
        - core
      exports:
        - PaymentRequest
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Api.eido", """
      class PaymentRequest {
        Money amount;
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
        - Core.eido
      children: []
      dependencies: []
      exports:
        - Money
        - Other
      provides: {}
      adopts: []
    """)
    writeFile(root / "core" / "Core.eido", """
      class Money {
        Int cents;
      }

      class Other {
        Int value;
      }
    """)

    writeFile(root / "api" / "module.yaml", """
      module: api
      sources:
        - Api.eido
      children: []
      dependencies:
        - core
      exports:
        - PaymentRequest
      provides: {}
      adopts: []
    """)
    writeFile(root / "api" / "Api.eido", """
      class PaymentRequest {
        Money amount;
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
