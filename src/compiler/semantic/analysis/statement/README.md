# Statement semantic-analysis ownership

Statement semantic dispatch remains coordinated by `../statement_analysis.nim`.

- `conditional_statements.nim` — Bool condition checking, isolated branch
  scopes, branch-local ID synchronization, and definite-return analysis

Future statement families should place feature-specific semantic rules here
rather than growing the coordinator.
