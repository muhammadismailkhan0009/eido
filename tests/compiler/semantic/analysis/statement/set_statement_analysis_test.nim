import std/unittest
import compiler/hir/[statements, expressions]
import support/compiler_test_support

suite "Set statement semantics":
  test "sets an existing primitive var":
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
    check program.functions[0].body[1].targetName == "value"

  test "allows replacing a class-valued var with a fresh construction":
    # Given
    let source = """
      class Marker {
        Int value;
      }

      function main() returns Int {
        var marker = Marker { value: 1; };
        set marker = Marker { value: 2; };
        return marker.value;
      }
    """

    # When
    let program = analyzeSource(source)

    # Then
    check program.functions[0].body[1].kind == hskAssign
    check program.functions[0].body[1].targetName == "marker"

  test "allows class-valued var mutation with explicit ref":
    # Given
    let source = """
      class Marker { Int value; }
      function main() returns Int {
        var first = Marker { value: 1; };
        var second = Marker { value: 2; };
        set second = ref first;
        return second.value;
      }
    """

    # When
    let body = analyzeSource(source).functions[0].body

    # Then
    check body[2].kind == hskAssign
    check body[2].assignedValue.kind == hekClassRelation
    check body[2].assignedValue.classRelationKind == hcvrRef

  test "allows class-valued var mutation with explicit copy":
    let source = """
      class Marker { Int value; }
      function main() returns Marker {
        var first = Marker { value: 1; };
        var second = Marker { value: 2; };
        set second = copy first;
        return second;
      }
    """

    let body = analyzeSource(source).functions[0].body
    check body[2].assignedValue.kind == hekClassRelation
    check body[2].assignedValue.classRelationKind == hcvrCopy

  test "set ref updates local provenance to existing identity":
    let source = """
      class Marker { Int value; }
      function choose(Marker source) returns Marker {
        var current = Marker { value: 0; };
        set current = ref source;
        return current;
      }
      function main() returns Int { return 0; }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects copy/ref mutation when the related class type mismatches":
    let source = """
      class First { Int value; }
      class Second { Int value; }
      function main() returns Int {
        var first = First { value: 1; };
        var second = Second { value: 2; };
        set second = ref first;
        return second.value;
      }
    """

    expect ValueError:
      discard analyzeSource(source)

  test "rejects class-valued var mutation from an existing class value":
    # Given
    let source = """
      class Marker {
        Int value;
      }

      function main() returns Int {
        var first = Marker { value: 1; };
        var second = Marker { value: 2; };
        set second = first;
        return second.value;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects parameter mutation":
    # Given
    let source = """
      function change(Int value) returns Int {
        set value = 20;
        return value;
      }

      function main() returns Int {
        return change(10);
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects an unknown set target":
    # Given
    let source = """
      function main() returns Int {
        set missing = 10;
        return 0;
      }
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "sets an own primitive field inside a method":
    # Given
    let source = """
      class Account {
        Int balance;

        function withdraw(Int amount) returns Int {
          set self.balance = self.balance - amount;
          return self.balance;
        }
      }

      function main() {}
    """

    # When
    let methodBody = analyzeSource(source).classes[0].methods[0].body

    # Then
    check methodBody[0].kind == hskFieldSet
    check methodBody[0].fieldName == "balance"

  test "allows fresh replacement of an own class-valued field":
    let source = """
      class Address { Int zip; }
      class Employee {
        Address address;
        function replace() {
          set self.address = Address { zip: 33100; };
        }
      }
      function main() {}
    """

    let body = analyzeSource(source).classes[1].methods[0].body
    check body[0].kind == hskFieldSet
    check body[0].fieldValue.kind == hekConstruct

  test "allows ref and copy replacement of an own class-valued field":
    let refSource = """
      class Address { Int zip; }
      class Employee {
        Address address;
        function replace(Address other) { set self.address = ref other; }
      }
      function main() {}
    """
    let copySource = """
      class Address { Int zip; }
      class Employee {
        Address address;
        function replace(Address other) { set self.address = copy other; }
      }
      function main() {}
    """

    let refValue = analyzeSource(refSource).classes[1].methods[0].body[0].fieldValue
    let copyValue = analyzeSource(copySource).classes[1].methods[0].body[0].fieldValue
    check refValue.kind == hekClassRelation
    check refValue.classRelationKind == hcvrRef
    check copyValue.kind == hekClassRelation
    check copyValue.classRelationKind == hcvrCopy

  test "rejects bare existing class value for own class-valued field replacement":
    # Given
    let source = """
      class Address {
        Int zip;
      }

      class Employee {
        Address address;

        function replace(Address other) {
          set self.address = other;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
