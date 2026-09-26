# Statement emitter ownership

Statement emission is coordinated by `../statement_emitter.nim`, which owns
shared indentation-aware dispatch.

- `conditional_statements.nim` — structured Nim `if`/`else` emission and recursive branch indentation
- `while_statements.nim` — structured Nim `while` emission and recursive body indentation
- `loop_control_statements.nim` — Nim `break`/`continue` emission

Future structured statement families should keep their rendering logic here.
