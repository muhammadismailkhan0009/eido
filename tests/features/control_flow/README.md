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

## While loops

`while_variants_test.nim` covers:

- repeated execution while the condition remains true
- zero iterations when initially false
- empty loop bodies
- nested loops
- Bool expression conditions
- mandatory condition parentheses
- non-Bool condition rejection
- loop-local scope isolation
- conservative return coverage

## Loop control

`loop_control_variants_test.nim` covers:

- early loop exit with `break;`
- skipping the rest of an iteration with `continue;`
- nearest-loop behavior for nested `break`
- nearest-loop behavior for nested `continue`
- rejection of both statements outside loops
