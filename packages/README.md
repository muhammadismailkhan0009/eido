# Eido packages

This area contains higher-level ordinary Eido libraries developed in the v0 monorepo. Packages build on Eido and the standard library and remain separate from compiler semantics.

Current packages:
- `testing/` — minimal reusable assertion helpers for Eido-owned package tests.
- `dependency-resolution/` — in-memory package/version dependency solver and future package-tooling core; owns its Eido tests under `tests/`.
