import std/[strutils, unittest, sequtils]
import project/model
import source/source_unit
import tooling/compiler_service

suite "Project compilation":
  test "resolves classes and functions across source files independent of source order":
    # Given
    let mainSource = initSourceUnit(0, "src/main.eido", """
      function main() returns Int {
        var account = Account { balance = 100; };
        return readBalance(account);
      }
    """)
    let accountSource = initSourceUnit(1, "src/account.eido", """
      class Account { Int balance; }
    """)
    let functionsSource = initSourceUnit(2, "src/functions.eido", """
      function readBalance(Account account) returns Int { return account.balance; }
    """)
    let forwardProject = initProject(ptExecutable, @[mainSource, accountSource, functionsSource])
    let reverseProject = initProject(ptExecutable, @[functionsSource, accountSource, mainSource])

    # When
    let forwardProgram = requireCheckedProject(forwardProject)
    let reverseProgram = requireCheckedProject(reverseProject)

    # Then
    check forwardProgram.classes.filterIt(not it.span.embeddedSdk).len == 1
    check forwardProgram.functions.len == 2
    check forwardProgram.classes[0].sourceName == "Account"
    check reverseProgram.classes.filterIt(not it.span.embeddedSdk).len == 1
    check reverseProgram.functions.len == 2

  test "retains layouts declared in a separate source unit":
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/layouts.eido", """
        layout Compact for Family {
          var shape = Layout.create();
          shape.field("father");
          return shape;
        }
      """),
      initSourceUnit(1, "src/family.eido", "class Family { Int father; }"),
      initSourceUnit(2, "src/main.eido", "function main() {}")
    ])
    let compiled = requireCheckedProject(project)
    check compiled.layouts.len == 1
    check compiled.layouts[0].targetClass == "Family"

  test "accepts a library project without main":
    # Given
    let project = initProject(ptLibrary, @[
      initSourceUnit(0, "src/math.eido",
        "function double(Int value) returns Int { return value * 2; }")
    ])

    # When
    let program = requireCheckedProject(project)

    # Then
    check program.functions.len == 1
    check not program.hasMain

  test "rejects an executable project without main":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/math.eido",
        "function double(Int value) returns Int { return value * 2; }")
    ])

    # When / Then
    expect ValueError:
      discard requireCheckedProject(project)

  test "reports the source path for a duplicate declaration":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/first.eido",
        "class Account { Int balance; }"),
      initSourceUnit(1, "src/second.eido",
        "class Account { Int balance; }"),
      initSourceUnit(2, "src/main.eido", "function main() {}")
    ])

    # When / Then
    try:
      discard requireCheckedProject(project)
      check false
    except ValueError as error:
      check "duplicate class 'Account'" in error.msg
      check "src/second.eido:" in error.msg

  test "reports the source path for a lexer failure":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/main.eido", "function main() { @ }")
    ])

    # When / Then
    try:
      discard requireCheckedProject(project)
      check false
    except ValueError as error:
      check "src/main.eido:" in error.msg


  test "reports the source path for a semantic failure inside a source unit":
    # Given
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "src/main.eido", "function main() { broken(); }")
    ])

    # When / Then
    try:
      discard requireCheckedProject(project)
      check false
    except ValueError as error:
      check "unknown function 'broken'" in error.msg
      check "src/main.eido:" in error.msg

  test "allows multiple standalone functions but isolates main":
    let project = initProject(ptExecutable, @[
      initSourceUnit(0, "Helpers.eido", "function first() {} function second() {}"),
      initSourceUnit(1, "Entry.eido", "// it's the entry point\nfunction main() { first(); second(); }")
    ])
    check checkProject(project).success

  test "rejects mixed file declarations in either order at the offending declaration":
    for source in [
      "class Box {}\nfunction helper() {}",
      "function helper() {}\nclass Box {}",
      "interface Service {}\nclass Box {}",
      "class Box {}\nlayout Compact for Box { return Layout.create(); }",
      "layout A for Box { return Layout.create(); }\nlayout B for Box { return Layout.create(); }",
      "function helper() {}\nLayoutPolicy.select(\"Box\", \"Compact\");",
      "LayoutPolicy.select(\"Box\", \"Compact\");\nLayoutPolicy.select(\"Box\", \"Other\");"
    ]:
      let checked = checkProject(initProject(ptLibrary, @[
        initSourceUnit(0, "Mixed.eido", source)
      ]))
      check not checked.success
      check checked.diagnostics[0].span.sourcePath == "Mixed.eido"
      check checked.diagnostics[0].span.line == 2
      check "only one non-function top-level declaration" in checked.diagnostics[0].message

  test "rejects main with any other top-level declaration":
    for other in ["function helper() {}", "native function helper();", "class Box {}",
                  "interface Service {}", "layout Compact for Box { return Layout.create(); }",
                  "LayoutPolicy.select(\"Box\", \"Compact\");", "function main() {}"]:
      for source in [other & "\nfunction main() {}", "function main() {}\n" & other]:
        let checked = checkProject(initProject(ptExecutable, @[
          initSourceUnit(0, "Entry.eido", source)
        ]))
        check not checked.success
        check checked.diagnostics[0].span.line == 2
        check "containing main" in checked.diagnostics[0].message

  test "permits class methods and comments without counting them as declarations":
    let checked = checkProject(initProject(ptLibrary, @[
      initSourceUnit(0, "Box.eido", "/// It's a box.\nclass Box { function first() {} function second() {} }")
    ]))
    check checked.success
