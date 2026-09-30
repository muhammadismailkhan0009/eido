import std/[os, strutils, unittest]
import project/model
import project/modules/loader
import source/source_unit
import tooling/[compiler_service, symbol_service]

suite "Semantic symbol tooling":
  test "indexes declarations and resolved references with definition locations":
    let source = """
class Account {
    Int balance;

    function read(Int bonus) returns Int {
        var total = self.balance + bonus;
        return total;
    }
}

function main() returns Int {
    var account = Account { balance = 41; };
    return account.read(1);
}
"""
    let project = initProject(
      ptExecutable,
      @[initSourceUnit(0, "main.eido", source)]
    )
    let program = requireCheckedProject(project)

    let symbols = buildSymbolIndex(program, project)

    let accountDecl = symbolAt(
      symbols,
      "main.eido",
      source.find("Account")
    )
    check accountDecl.found
    check accountDecl.symbol.kind == tskClass
    check accountDecl.symbol.isDeclaration

    let fieldUseOffset = source.find("balance +")
    let fieldUse = symbolAt(symbols, "main.eido", fieldUseOffset)
    check fieldUse.found
    check fieldUse.symbol.kind == tskProperty
    check not fieldUse.symbol.isDeclaration
    check fieldUse.symbol.declarationSpan.startOffset ==
      source.find("balance;")

    let parameterUseOffset = source.find("bonus;")
    let parameterUse = symbolAt(symbols, "main.eido", parameterUseOffset)
    check parameterUse.found
    check parameterUse.symbol.kind == tskParameter
    check parameterUse.symbol.declarationSpan.startOffset ==
      source.find("bonus)")

    let localUseOffset = source.find("total;")
    let localUse = symbolAt(symbols, "main.eido", localUseOffset)
    check localUse.found
    check localUse.symbol.kind == tskVariable
    check localUse.symbol.declarationSpan.startOffset ==
      source.find("total =")

    let methodUseOffset = source.rfind("read")
    let methodUse = symbolAt(symbols, "main.eido", methodUseOffset)
    check methodUse.found
    check methodUse.symbol.kind == tskMethod
    check methodUse.symbol.declarationSpan.startOffset ==
      source.find("read(")

    let constructorOffset = source.rfind("Account")
    let constructorUse = symbolAt(symbols, "main.eido", constructorOffset)
    check constructorUse.found
    check constructorUse.symbol.kind == tskClass
    check constructorUse.symbol.declarationSpan.startOffset ==
      source.find("Account")

  test "marks static and instance method declarations distinctly":
    let source = """
class Factory {
    Int stored;

    function create() returns Int {
        return 1;
    }

    function read() returns Int {
        return self.value();
    }

    function value() returns Int {
        return self.stored;
    }
}

function main() returns Int {
    return Factory.create();
}
"""
    let project = initProject(
      ptExecutable,
      @[initSourceUnit(0, "main.eido", source)]
    )
    let program = requireCheckedProject(project)
    let symbols = buildSymbolIndex(program, project)

    let createDecl = symbolAt(symbols, "main.eido", source.find("create()"))
    check createDecl.found
    check createDecl.symbol.kind == tskMethod
    check createDecl.symbol.isDeclaration
    check createDecl.symbol.isStatic

    let readDecl = symbolAt(symbols, "main.eido", source.find("read()"))
    check readDecl.found
    check readDecl.symbol.kind == tskMethod
    check readDecl.symbol.isDeclaration
    check not readDecl.symbol.isStatic

  test "resolves cross-file module method definition":
    let root =
      getTempDir() / ("eido_symbol_definition_" & $getCurrentProcessId())
    if dirExists(root):
      removeDir(root)
    createDir(root)
    defer:
      if dirExists(root):
        removeDir(root)

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
        - Factory.eido
      children: []
      dependencies: []
      exports:
        - Factory
      provides: {}
      adopts: []
    """)
    let factoryPath = root / "api" / "Factory.eido"
    let factorySource = """
class Factory {
    function value() returns Int {
        return 42;
    }
}
"""
    writeFile(factoryPath, factorySource)

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
    let mainPath = root / "app" / "Main.eido"
    let mainSource = """
function main() returns Int {
    return Factory.value();
}
"""
    writeFile(mainPath, mainSource)

    let project = loadModuleProject(root / "module.yaml", ptLibrary)
    let program = requireCheckedProject(project)
    let symbols = buildSymbolIndex(program, project)
    let useOffset = mainSource.rfind("value")

    let matched = symbolAt(symbols, mainPath, useOffset)

    check matched.found
    check matched.symbol.kind == tskMethod
    check matched.symbol.declarationSpan.sourcePath == factoryPath
    check matched.symbol.declarationSpan.startOffset ==
      factorySource.find("value")

  test "resolves inherited interface method definition":
    let readableSource = """
interface Readable {
    function read() returns Int;
}
"""
    let detailedSource = """
interface DetailedReadable extends Readable {
    function detail() returns Int;
}
"""
    let valueSource = """
class Value implements DetailedReadable {
    Int stored;

    function read() returns Int {
        return self.stored;
    }

    function detail() returns Int {
        return self.stored + 1;
    }
}
"""
    let mainSource = """
function consume(DetailedReadable value) returns Int {
    return value.read();
}

function main() returns Int {
    return consume(Value { stored = 41; });
}
"""
    let project = initProject(
      ptExecutable,
      @[
        initSourceUnit(0, "Readable.eido", readableSource),
        initSourceUnit(1, "DetailedReadable.eido", detailedSource),
        initSourceUnit(2, "Value.eido", valueSource),
        initSourceUnit(3, "main.eido", mainSource)
      ]
    )
    let program = requireCheckedProject(project)
    let symbols = buildSymbolIndex(program, project)

    let readUse = symbolAt(
      symbols,
      "main.eido",
      mainSource.rfind("read")
    )

    check readUse.found
    check readUse.symbol.kind == tskMethod
    check readUse.symbol.declarationSpan.sourcePath == "Readable.eido"
    check readUse.symbol.declarationSpan.startOffset ==
      readableSource.find("read()")
