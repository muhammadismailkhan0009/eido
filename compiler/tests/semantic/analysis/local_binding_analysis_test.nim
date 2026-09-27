import std/unittest
import hir/statements
import support/compiler_test_support

suite "Local binding analysis":
  test "resolves a local after its initializer has been checked":
    # Given
    let source = """
      function main() returns Int {
        var salary = 5000;
        var total = salary + 500;
        return total;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[0].kind == hskVar
    check program.functions[0].body[1].kind == hskVar
    check program.functions[0].body[2].kind == hskReturn

  test "rejects a bare identifier initializer":
    # Given
    let source = """
      function main() returns Int {
        var a = 5;
        var b = a;
        return b;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects a local used before declaration":
    # Given
    let source = """
      function main() returns Int {
        var value = later + 1;
        var later = 5;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects self reference in an initializer":
    # Given
    let source = """
      function main() returns Int {
        var value = value + 1;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects duplicate locals in the same scope":
    # Given
    let source = """
      function main() returns Int {
        var value = 1;
        var value = 2;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "allows set mutation of an existing primitive local":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        set value = value + 1;
        return value;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[1].kind == hskAssign

  test "allows set from another existing primitive local":
    # Given
    let source = """
      function main() returns Int {
        var a = 5;
        var b = 10;
        set b = a;
        return b;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[2].kind == hskAssign

  test "rejects an unknown set target":
    # Given
    let source = """
      function main() returns Int {
        set missing = 5;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects an unknown identifier on set right hand side":
    # Given
    let source = """
      function main() returns Int {
        var value = 5;
        set value = missing + 1;
        return value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects a local that redeclares a parameter":
    # Given
    let source = """
      function identity(Int value) returns Int {
        var value = 5;
        return value;
      }
      function main() returns Int { return identity(10); }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects parameter mutation with set":
    # Given
    let source = """
      function change(Int value) returns Int {
        set value = 20;
        return value;
      }
      function main() returns Int { return change(10); }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
