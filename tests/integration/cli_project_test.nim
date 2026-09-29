import std/[os, osproc, strutils, unittest]
import cli/[arguments, build_command, check_command]

proc freshProject(name: string): string =
  result = getTempDir() / ("eido_cli_" & name & "_" & $getCurrentProcessId())
  if dirExists(result):
    removeDir(result)
  createDir(result)

suite "CLI project integration":
  test "parses manifest-driven build with output option":
    let options = parseArgs(@[
      "build", "shop/module.yaml", "-o", "bin/app"
    ])

    check options.command == ccBuild
    check options.modulePath == "shop/module.yaml"
    check options.outputPath == "bin/app"

  test "parses manifest-driven check":
    let options = parseArgs(@["check", "shop/module.yaml"])

    check options.command == ccCheck
    check options.modulePath == "shop/module.yaml"

  test "rejects source-file project entrypoints":
    expect ValueError:
      discard parseArgs(@["check", "src/main.eido"])

  test "checks a module project without invoking backend compilation":
    let root = freshProject("check")
    let generatedPath = root / "generated.nim"
    defer:
      if dirExists(root):
        removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
        - Account.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() {
        var account = Account { balance = 42; };
        read(account);
      }
    """)
    writeFile(root / "Account.eido", """
      class Account { Int balance; }
      function read(Account account) returns Int { return account.balance; }
    """)

    let result = checkModuleFile(root / "module.yaml")

    check result.success
    check result.diagnostics.len == 0
    check not fileExists(generatedPath)

  test "returns structured diagnostics from module check":
    let root = freshProject("check_error")
    defer:
      if dirExists(root):
        removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", "function main() { broken(); }")

    let result = checkModuleFile(root / "module.yaml")

    check not result.success
    check result.diagnostics.len == 1
    check result.diagnostics[0].code == "EIDO1000"
    check result.diagnostics[0].span.sourcePath == root / "Main.eido"

  test "builds a multi-source module project into one native executable":
    let root = freshProject("build")
    let outputPath = root / "app"
    defer:
      if dirExists(root):
        removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
        - Account.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      function main() returns Int {
        var account = Account { balance = 42; };
        return read(account);
      }
    """)
    writeFile(root / "Account.eido", """
      class Account { Int balance; }
      function read(Account account) returns Int { return account.balance; }
    """)

    buildModuleFile(root / "module.yaml", outputPath)
    let output = execProcess(outputPath).strip()

    check output == "42"


  test "builds module interface provider and dispatches through public contract":
    let root = freshProject("interface_modules")
    let outputPath = root / "interface_app"
    defer:
      if dirExists(root):
        removeDir(root)

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

        function value() returns Int {
          return self.stored;
        }
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

    buildModuleFile(root / "module.yaml", outputPath)
    check execProcess(outputPath).strip() == "42"


  test "builds exported interface with transitive ordinary class API":
    let root = freshProject("class_api_closure")
    let outputPath = root / "class_api_app"
    defer:
      if dirExists(root):
        removeDir(root)

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
        - PaymentRequest.eido
        - PaymentResult.eido
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
    writeFile(root / "payments" / "PaymentRequest.eido", """
      class PaymentRequest {
        Int amount;

        function doubled() returns Int {
          return self.amount * 2;
        }
      }
    """)
    writeFile(root / "payments" / "PaymentResult.eido", "class PaymentResult { Int code; }")
    writeFile(root / "payments" / "PaymentService.eido", """
      interface PaymentService {
        function pay(PaymentRequest request) returns PaymentResult;
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
        Int offset;

        function pay(PaymentRequest request) returns PaymentResult {
          return PaymentResult {
            code = request.doubled() + self.offset;
          };
        }
      }
    """)
    writeFile(root / "payments" / "processor" / "ProcessorFactory.eido", """
      class ProcessorFactory {
        function create() returns PaymentService {
          return HiddenService { offset = 0; };
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
        var request = PaymentRequest { amount = 21; };
        var service = Payments.service();
        var outcome = service.pay(request);
        return outcome.code;
      }
    """)

    buildModuleFile(root / "module.yaml", outputPath)
    check execProcess(outputPath).strip() == "42"

  test "builds duplicate module-local class names with explicit qualification":
    let root = freshProject("qualified_nominals")
    let outputPath = root / "qualified_app"
    defer:
      if dirExists(root):
        removeDir(root)

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
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    writeFile(root / "payments" / "Result.eido", "class Result { Int code; }")
    writeFile(root / "payments" / "Factory.eido", """
      class Factory {
        function create() returns Result {
          return Result { code = 20; };
        }
      }
    """)

    writeFile(root / "users" / "module.yaml", """
      module: users
      sources:
        - Result.eido
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    writeFile(root / "users" / "Result.eido", "class Result { Int score; }")
    writeFile(root / "users" / "Factory.eido", """
      class Factory {
        function create() returns Result {
          return Result { score = 22; };
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
        - users
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "app" / "Main.eido", """
      function readPayment(payments.Result value) returns Int {
        return value.code;
      }

      function readUser(users.Result value) returns Int {
        return value.score;
      }

      function main() returns Int {
        var payment = payments.Factory.create();
        var user = users.Factory.create();
        return readPayment(payment) + readUser(user);
      }
    """)

    buildModuleFile(root / "module.yaml", outputPath)
    check execProcess(outputPath).strip() == "42"

  test "builds module project with class-owned native method":
    let root = freshProject("module_native_method")
    let outputPath = root / "native_app"
    defer:
      if dirExists(root):
        removeDir(root)

    writeFile(root / "module.yaml", """
      module: app
      sources:
        - Main.eido
      children: []
      dependencies: []
      exports: []
      provides: {}
      adopts: []
    """)
    writeFile(root / "Main.eido", """
      class Console {
        native function writeLine(String value);
      }

      function main() {
        Console.writeLine("hello");
      }
    """)

    buildModuleFile(root / "module.yaml", outputPath)
    check execProcess(outputPath).strip() == "hello"
