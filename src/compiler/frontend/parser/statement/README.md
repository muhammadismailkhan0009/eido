# Statement parser ownership

Statement-family parsing remains coordinated by `../statement_parser.nim`.

- `braced_blocks.nim` — shared parsing mechanics for braced structured-statement bodies
- `conditional_statements.nim` — `if` / chained `else if` / optional final `else` grammar
- `while_statements.nim` — parenthesized `while` condition and loop-body grammar
- `for_statements.nim` — classic declaration-condition-update `for` grammar
- `loop_control_statements.nim` — semicolon-terminated `break` and `continue` syntax

As more independently meaningful statement families are added, move their
parsing rules here rather than growing the coordinator.
