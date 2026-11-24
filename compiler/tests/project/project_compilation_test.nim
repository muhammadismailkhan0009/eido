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
      function readBalance(Account account) returns Int { return account.balance; }
    """)
    let forwardProject = initProject(ptExecutable, @[mainSource, accountSource])
    let reverseProject = initProject(ptExecutable, @[accountSource, mainSource])

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
        "class Account { Int balance; } function main() {}"),
      initSourceUnit(1, "src/second.eido",
        "class Account { Int balance; }")
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
