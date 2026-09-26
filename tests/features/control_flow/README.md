# Control-flow feature coverage

This directory contains user-facing acceptance scenarios for Eido control flow.

## Conditional statements

`conditional_variants_test.nim` covers:

- true `if` branch execution
- false `if` fall-through without `else`
- `else` selection
- assignment to an existing outer local from a branch
- nested conditionals
- required parenthesized `if` conditions
- Bool-only condition typing
- branch-local name isolation
- result functions ending in an all-returning `if/else`
- rejection when a final branch can fall through

`else_if_variants_test.nim` covers:

- selecting an `else if` branch
- multiple chained `else if` branches
- final `else` fallback
- fall-through when a chain has no final `else`
- mandatory parentheses around every `else if` condition

Semantic compiler tests additionally verify Bool typing and definite-return
analysis across `else if` chains, plus unique function-wide semantic IDs for
branch locals.
