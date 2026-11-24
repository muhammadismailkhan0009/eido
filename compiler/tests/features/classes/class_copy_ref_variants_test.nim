import std/unittest
import support/feature_test_support

import support/feature_batch_support

suite "Class copy/ref execution":
  test "native cases group 1":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "ref local preserves the same object identity", source: """
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
    """, expected: "70"),
      NativeFeatureCase(name: "copy local creates a detached object", source: """
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
    """, expected: "100070"),
      NativeFeatureCase(name: "class parameter preserves caller identity", source: """
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
    """, expected: "80"),
    ], "class_copy_ref_execution_1")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "native cases group 2":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "construction fields choose ref or detached copy explicitly", source: """
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
    """, expected: "909080"),
      NativeFeatureCase(name: "copy recursively detaches nested class state", source: """
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
    """, expected: "100080"),
      NativeFeatureCase(name: "copy preserves sharing inside the detached graph", source: """
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
    """, expected: "100080"),
    ], "class_copy_ref_execution_2")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "native cases group 3":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "copy preserves cycles inside the detached graph", source: """
      class Node {
        Node? next;
        Int value;
        function link(Node other) { set self.next = ref other; }
        function bump() { set self.value = self.value + 1; }
      }

      function main() returns Int {
        var left = Node { next = none; value = 1; };
        var right = Node { next = none; value = 2; };
        left.link(right);
        right.link(left);
        var detached = copy left;
        if detached.next exists {
          if detached.next.next exists {
            detached.next.next.bump();
          }
        }
        return left.value * 100 + detached.value;
      }
    """, expected: "102"),
      NativeFeatureCase(name: "copy memo grows and resets between operations", source: """
      class Node {
        Node? next;
        Int value;
        function link(Node other) { set self.next = ref other; }
        function sum() returns Int {
          if self.next exists { return self.value + self.next.sum(); }
          return self.value;
        }
      }

      function main() returns Int {
        var one = Node { next = none; value = 1; };
        var two = Node { next = none; value = 2; };
        var three = Node { next = none; value = 3; };
        var four = Node { next = none; value = 4; };
        var five = Node { next = none; value = 5; };
        var six = Node { next = none; value = 6; };
        one.link(two);
        two.link(three);
        three.link(four);
        four.link(five);
        five.link(six);
        var firstCopy = copy one;
        var secondCopy = copy one;
        return firstCopy.sum() * 100 + secondCopy.sum();
      }
    """, expected: "2121"),
    ], "class_copy_ref_execution_3")
    check results.len == 2
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

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
  test "native cases group 1":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "copy and ref may bind an existing class-valued field", source: """
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
    """, expected: "909080"),
      NativeFeatureCase(name: "class-valued static method parameter preserves caller identity", source: """
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
    """, expected: "75"),
      NativeFeatureCase(name: "detached callable result may flow into construction and set", source: """
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
    """, expected: "4070"),
    ], "class_relation_boundary_execution_1")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

suite "Class relationship mutation execution":
  test "native cases group 1":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "set ref rebinds a class local to existing identity", source: """
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
    """, expected: "80"),
      NativeFeatureCase(name: "set copy rebinds a class local to detached identity", source: """
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
    """, expected: "100080"),
      NativeFeatureCase(name: "set self field ref preserves supplied identity", source: """
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
    """, expected: "80"),
    ], "class_relationship_mutation_execution_1")
    check results.len == 3
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected

  test "native cases group 2":
    let results = runNativeFeatureBatch(@[
      NativeFeatureCase(name: "set self field copy detaches supplied identity", source: """
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
    """, expected: "100080"),
      NativeFeatureCase(name: "set self field accepts fresh and detached callable results", source: """
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
    """, expected: "4070"),
    ], "class_relationship_mutation_execution_2")
    check results.len == 2
    for item in results:
      checkpoint(item.name)
      check item.actual == item.expected
