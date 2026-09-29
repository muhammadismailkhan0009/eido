import std/[strutils, unittest]
import support/compiler_test_support

suite "Contract emission":
  test "emits require ensure and invariant runtime checks":
    let source = """
      class Account {
        Int balance;
        invariant { self.balance >= 0; }

        function debit(Int amount) {
          require { amount > 0; }
          set self.balance = self.balance - amount;
          ensure { self.balance >= 0; }
        }
      }
      function main() {
        var account = Account { balance = 10; };
        account.debit(1);
      }
    """

    let generated = emitSource(source)

    check "require contract failed in method 'debit'" in generated
    check "ensure contract failed in method 'debit'" in generated
    check "invariant contract failed for class 'Account'" in generated
    check "eido_invariant_Account(eido_class_Account(" in generated


  test "does not lower ensure through defer":
    let source = """
      function checked(Int value) returns Int {
        return value;
        ensure { value > 0; }
      }
      function main() {}
    """

    let generated = emitSource(source)

    check "ensure contract failed in function 'checked'" in generated
    check "defer:\n    if not" notin generated
    check "eido_local_1_result" in generated


  test "checks invariants immediately after self field mutation":
    let source = """
      class Account {
        Int balance;
        invariant { self.balance > 0; }
        function update(Int value) {
          set self.balance = value;
        }
      }
      function main() {}
    """

    let generated = emitSource(source)
    let assignment = generated.find("eido_field_balance = eido_local_1_value")
    let mutationCheck = generated.find("discard eido_invariant_Account", assignment)

    check assignment >= 0
    check mutationCheck > assignment


  test "uses invariant evaluation guard only inside the checker":
    let source = """
      class Account {
        Int balance;
        invariant { self.valid(); }
        function valid() returns Bool { return self.balance > 0; }
        function inspect() { if (self.balance > 0) {} }
      }
      function main() {}
    """

    let generated = emitSource(source)
    let checkerStart = generated.find("proc eido_invariant_Account")
    let validStart = generated.find("proc eido_method_0_Account_valid", checkerStart + 1)
    let inspectStart = generated.find("proc eido_method_1_Account_inspect", validStart + 1)
    let checkerBody = generated[checkerStart ..< validStart]
    let validBody = generated[validStart ..< inspectStart]

    check "eido_runtime_invariant_evaluation_depth += 1" in checkerBody
    check "eido_runtime_invariant_evaluation_depth += 1" notin validBody
    check "if eido_local_0_receiver.eido_runtime_invariant_evaluation_depth == 0:" in validBody


  test "binds ensure result before checking the postcondition":
    let source = """
      function checked(Int value) returns Int {
        return value + 1;
        ensure { result > value; }
      }
      function main() {}
    """

    let generated = emitSource(source)
    let binding = generated.find("let eido_local_1_result =")
    let ensureCheck = generated.find("ensure contract failed in function 'checked'", binding)
    let returned = generated.find("return eido_local_1_result", ensureCheck)

    check binding >= 0
    check ensureCheck > binding
    check returned > ensureCheck
    check generated.count("(eido_local_0_value + int64(1))") == 1
