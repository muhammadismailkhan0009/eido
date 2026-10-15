# Eido testing package

Minimal reusable assertions for package-owned Eido tests.

Current API:

```text
Assert.fail
Assert.isTrue
Assert.isFalse
Assert.equalInt
Assert.equalString
```

Assertion failure writes a diagnostic to stderr and terminates the test process with a non-zero exit code. This package is developer tooling, not part of the standard library.
