# Eido CLI

The installed front door remains the single `eido` command.

- `src/` is the temporary Nim bootstrap adapter. It currently owns `build` and `check` while the Eido implementation grows.
- `eido/` is the permanent CLI implementation written in Eido itself. It currently owns permanent shell behavior for `help`, `version`, unknown-command diagnostics, and exit status.

Migration is requirement-driven: when the Eido CLI needs a capability that Eido cannot yet express, implement that capability at the correct language/stdlib/package/compiler-tooling layer, then extend the Eido CLI and eventually remove the corresponding bootstrap Nim responsibility.
