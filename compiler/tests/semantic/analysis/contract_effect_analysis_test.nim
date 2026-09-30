import std/unittest
import support/compiler_test_support

suite "Contract effect safety":
  test "allows transitively read-only helper calls in contracts":
    # Given
    let source = """
      function positive(Int value) returns Bool {
        return value > 0;
      }

      function acceptable(Int value) returns Bool {
        return positive(value);
      }

      function checked(Int value) {
        require { acceptable(value); }
      }

      function main() { checked(1); }
    """

    # When / Then
    discard analyzeSource(source)

  test "allows local mutation inside a contract-safe helper":
    # Given
    let source = """
      function normalized(Int value) returns Bool {
        var working = value + 0;
        set working = working + 1;
        return working > 0;
      }

      function checked(Int value) {
        require { normalized(value); }
      }

      function main() { checked(1); }
    """

    # When / Then
    discard analyzeSource(source)

  test "allows Storage layout queries inside contracts":
    # Given
    let source = """
      function checked() {
        require {
          Storage<Int>.size() > 0;
          Storage<Int>.alignment() > 0;
        }
      }

      function main() { checked(); }
    """

    # When / Then
    discard analyzeSource(source)

  test "rejects a directly mutating method called from a contract":
    # Given
    let source = """
      class Account {
        Int balance;

        function mutateAndCheck() returns Bool {
          set self.balance = self.balance + 1;
          return true;
        }

        function checked() {
          require { self.mutateAndCheck(); }
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects transitively mutating calls from a contract":
    # Given
    let source = """
      class Account {
        Int balance;

        function mutateAndCheck() returns Bool {
          set self.balance = self.balance + 1;
          return true;
        }

        function appearsReadOnly() returns Bool {
          return self.mutateAndCheck();
        }

        function checked() {
          require { self.appearsReadOnly(); }
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects native calls from contracts because effects are unverifiable":
    # Given
    let source = """
      native function nativeCheck(Int value) returns Bool;

      function checked(Int value) {
        require { nativeCheck(value); }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "rejects dynamic interface dispatch from contracts":
    # Given
    let source = """
      interface Validator {
        function valid() returns Bool;
      }

      function checked(Validator validator) {
        require { validator.valid(); }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "applies effect safety to ensure clauses":
    # Given
    let source = """
      class Account {
        Int balance;

        function mutateAndCheck() returns Bool {
          set self.balance = self.balance + 1;
          return true;
        }

        function checked() {
          ensure { self.mutateAndCheck(); }
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)

  test "applies effect safety to class invariants":
    # Given
    let source = """
      class Account {
        Int balance;

        invariant { self.mutateAndCheck(); }

        function mutateAndCheck() returns Bool {
          set self.balance = self.balance + 1;
          return true;
        }
      }

      function main() {}
    """

    # When / Then
    expect ValueError:
      discard analyzeSource(source)
