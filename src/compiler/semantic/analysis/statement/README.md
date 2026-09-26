# Statement semantic-analysis ownership

Statement semantic dispatch remains coordinated by `../statement_analysis.nim`.

- `scoped_blocks.nim` — shared isolated child-scope analysis and LocalId synchronization
- `conditional_statements.nim` — Bool condition checking and definite-return analysis for conditional chains
- `while_statements.nim` — Bool loop conditions and isolated loop-body semantics
- `loop_control_statements.nim` — loop-depth validation and HIR lowering for `break`/`continue`

A `while` statement is deliberately not classified as definitely returning,
because its body may execute zero times.

Future statement families should place feature-specific semantic rules here
rather than growing the coordinator.
