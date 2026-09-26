# Statement emitter ownership

Statement emission is coordinated by `../statement_emitter.nim`, which owns
shared indentation-aware dispatch.

- `conditional_statements.nim` — structured Nim `if`/`else` emission and
  recursive branch indentation

Future structured statement families should keep their rendering logic here.
