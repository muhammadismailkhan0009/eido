import std/unittest
import support/feature_test_support

suite "Class copy/ref execution":
  test "ref local preserves the same object identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var alias = ref account;
        alias.withdraw(30);
        return account.value();
      }
    """

    check runFeatureSource(source, "class_ref_alias") == "70"

  test "copy local creates a detached object":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var detached = copy account;
        detached.withdraw(30);
        return account.value() * 1000 + detached.value();
      }
    """

    check runFeatureSource(source, "class_copy_detached") == "100070"

  test "class parameter preserves caller identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      function charge(Account account, Int amount) {
        account.withdraw(amount);
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        charge(account, 20);
        return account.value();
      }
    """

    check runFeatureSource(source, "class_parameter_identity") == "80"

  test "construction fields choose ref or detached copy explicitly":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      class Pair {
        Account shared;
        Account detached;
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var pair = Pair {
          shared = ref account;
          detached = copy account;
        };
        pair.shared.withdraw(10);
        pair.detached.withdraw(20);
        return account.value() * 10000 +
          pair.shared.value() * 100 +
          pair.detached.value();
      }
    """

    check runFeatureSource(source, "construction_copy_ref") == "909080"

  test "copy recursively detaches nested class state":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      class Customer {
        Account account;
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var customer = Customer { account = ref account; };
        var detached = copy customer;
        detached.account.withdraw(20);
        return account.value() * 1000 + detached.account.value();
      }
    """

    check runFeatureSource(source, "nested_copy_detached") == "100080"

  test "copy preserves sharing inside the detached graph":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      class Pair {
        Account first;
        Account second;
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var pair = Pair {
          first = ref account;
          second = ref account;
        };
        var detached = copy pair;
        detached.first.withdraw(20);
        return account.value() * 1000 + detached.second.value();
      }
    """

    check runFeatureSource(source, "copy_preserves_sharing") == "100080"

suite "Class return detachment execution":
  test "mutate original then return detached snapshot":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) {
          set self.balance = self.balance - amount;
        }
        function value() returns Int { return self.balance; }
      }

      function modify(Account account) returns Account {
        account.withdraw(10);
        var modifiedAccount = copy account;
        return modifiedAccount;
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        var outcome = modify(account);
        outcome.withdraw(20);
        return account.value() * 1000 + outcome.value();
      }
    """

    check runFeatureSource(source, "mutate_then_snapshot") == "90070"

suite "Class relation boundary execution":
  test "copy and ref may bind an existing class-valued field":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) { set self.balance = self.balance - amount; }
        function value() returns Int { return self.balance; }
      }
      class Order { Account account; }

      function main() returns Int {
        var account = Account { balance = 100; };
        var order = Order { account = ref account; };
        var alias = ref order.account;
        var detached = copy order.account;
        alias.withdraw(10);
        detached.withdraw(20);
        return account.value() * 10000 +
          order.account.value() * 100 + detached.value();
      }
    """

    check runFeatureSource(source, "field_copy_ref_binding") == "909080"

  test "class-valued static method parameter preserves caller identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) { set self.balance = self.balance - amount; }
        function value() returns Int { return self.balance; }
      }
      class Charger {
        function charge(Account account, Int amount) {
          account.withdraw(amount);
        }
      }

      function main() returns Int {
        var account = Account { balance = 100; };
        Charger.charge(account, 25);
        return account.value();
      }
    """

    check runFeatureSource(source, "method_class_parameter_identity") == "75"

  test "detached callable result may flow into construction and set":
    let source = """
      class Account {
        Int balance;
        function value() returns Int { return self.balance; }
      }
      class Holder { Account account; }

      function create(Int balance) returns Account {
        return Account { balance = balance; };
      }

      function main() returns Int {
        var holder = Holder { account = create(40); };
        var account = Account { balance = 10; };
        set account = create(70);
        return holder.account.value() * 100 + account.value();
      }
    """

    check runFeatureSource(source, "detached_callable_flow") == "4070"

suite "Class relationship mutation execution":
  test "set ref rebinds a class local to existing identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) { set self.balance = self.balance - amount; }
        function value() returns Int { return self.balance; }
      }
      function main() returns Int {
        var first = Account { balance = 100; };
        var current = Account { balance = 5; };
        set current = ref first;
        current.withdraw(20);
        return first.value();
      }
    """

    check runFeatureSource(source, "class_set_ref_local") == "80"

  test "set copy rebinds a class local to detached identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) { set self.balance = self.balance - amount; }
        function value() returns Int { return self.balance; }
      }
      function main() returns Int {
        var first = Account { balance = 100; };
        var current = Account { balance = 5; };
        set current = copy first;
        current.withdraw(20);
        return first.value() * 1000 + current.value();
      }
    """

    check runFeatureSource(source, "class_set_copy_local") == "100080"
  test "set self field ref preserves supplied identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) { set self.balance = self.balance - amount; }
        function value() returns Int { return self.balance; }
      }
      class Holder {
        Account account;
        function replace(Account other) { set self.account = ref other; }
      }
      function main() returns Int {
        var first = Account { balance = 10; };
        var second = Account { balance = 100; };
        var holder = Holder { account = ref first; };
        holder.replace(second);
        holder.account.withdraw(20);
        return second.value();
      }
    """

    check runFeatureSource(source, "class_set_ref_field") == "80"

  test "set self field copy detaches supplied identity":
    let source = """
      class Account {
        Int balance;
        function withdraw(Int amount) { set self.balance = self.balance - amount; }
        function value() returns Int { return self.balance; }
      }
      class Holder {
        Account account;
        function replace(Account other) { set self.account = copy other; }
      }
      function main() returns Int {
        var first = Account { balance = 10; };
        var second = Account { balance = 100; };
        var holder = Holder { account = ref first; };
        holder.replace(second);
        holder.account.withdraw(20);
        return second.value() * 1000 + holder.account.value();
      }
    """

    check runFeatureSource(source, "class_set_copy_field") == "100080"
  test "set self field accepts fresh and detached callable results":
    let source = """
      class Account {
        Int balance;
        function value() returns Int { return self.balance; }
      }
      class Holder {
        Account account;
        function replaceFresh(Int balance) {
          set self.account = Account { balance = balance; };
        }
        function replaceCall(Int balance) {
          set self.account = create(balance);
        }
      }
      function create(Int balance) returns Account {
        return Account { balance = balance; };
      }
      function main() returns Int {
        var holder = Holder { account = Account { balance = 1; }; };
        holder.replaceFresh(40);
        var first = holder.account.value();
        holder.replaceCall(70);
        return first * 100 + holder.account.value();
      }
    """

    check runFeatureSource(source, "class_set_fresh_field") == "4070"
