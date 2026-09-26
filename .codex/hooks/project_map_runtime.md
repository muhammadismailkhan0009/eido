# Project Map Runtime

Reduce repository rediscovery and read/search tokens. Maintain exactly one navigation cache at `<repo>/.project-map.md`.

The map is a routing cache, not documentation, history, task memory, or source of truth.

## Hard boundaries

- Keep exactly one `.project-map.md`. Do not create indexes, databases, per-module memory files, changelogs, task files, or generated knowledge stores.
- Consult the injected/current `.project-map.md` before invoking other development skills or broadly exploring source.
- Except for first-time bootstrap when the file is missing, do not maintain/rewrite the map before or during the primary requested work. Finish the user's requested repository work first; reconcile the map afterward.
- Current source is authoritative. Before editing code, read the actual target files even when the map names them.
- Never recursively scan or broadly read the repository merely to enrich or validate the map.
- Record only verified facts supported by current project evidence. Omit uncertainty rather than storing guesses.
- Every physical file reference must include its filename extension, e.g. `AuthenticationService.java`, `package.json`, `routes.ts`. Default to the bare filename. Add only the shortest path needed when the filename is ambiguous in the repository or when path context materially improves routing. Do not repeat long physical paths when a filename or short disambiguating path is sufficient. Directory references end in `/`.
- Routes point to physical files or directories, not bare class/interface/method symbols.
- Avoid line numbers, copied code, method bodies, large signatures, raw command output, and exhaustive symbol/file lists.
- The map is rewritten knowledge, never an append-only log. Replace stale facts, merge duplicates, and delete low-value entries.
- Never store secrets, credentials, tokens, sensitive values, or private data.
- Target <= 8 KiB. Prune aggressively above 8 KiB; never exceed 12 KiB without explicit user preference.

## Mandatory preflight

For every repository development task:

1. Resolve the repository root.
2. If `.project-map.md` does not exist, bootstrap it automatically using the project-map installation reference before invoking another development skill or broadly exploring source.
3. Use the hook-injected map first when available. If hooks are unavailable/untrusted, consult `.project-map.md` directly.
4. Use mapped routes, ownership, flows, and invariants to choose the smallest plausible source shortlist.
5. Perform the user's requested work normally using current source as authority.
6. Fall back to repository `rg`/find/listing/reference searches only when the map is insufficient, stale, or exact usages/callers are required.
7. Keep fallback search narrow. Do not read unrelated matches merely to understand the repository generally.
8. Do not rewrite the map yet. Retain useful navigation knowledge learned during the work for end-of-turn reconciliation.

The map answers **where should I look?** Repository search answers **what exactly exists now?**

## During the requested work: observe, do not maintain

While analyzing, coding, debugging, testing, reviewing, or otherwise performing the user's requested repository work:

- use the map for navigation;
- trust current source over map contents;
- note useful navigation facts, map misses, stale entries, ownership discoveries, flows, invariants, moves/renames, and source-of-truth files as they become evident;
- treat all repository evidence encountered during the turn as eligible, regardless of whether it belongs to the requested feature or changed files;
- do not interrupt the primary task merely to update `.project-map.md`;
- do not run extra searches solely to improve the map.

If the map is stale during the task, route using current source and remember the correction for the end-of-turn rewrite.

## Admission policy

Admit an entry only if it is likely to prevent a future repository search or unnecessary read.

High-value entries are:

- **Route:** task/concept -> best physical file(s) or area to inspect first.
- **Ownership:** behavior-owning file/module -> responsibility it actually owns.
- **Flow:** important cross-file execution/data path needed to navigate a feature.
- **Boundary/invariant:** non-obvious architectural rule that changes where future work belongs.
- **Source of truth:** file that definitively owns a schema/configuration/contract when that fact prevents repeated hunting.

Be reasonably aggressive about file-level ownership for behavior-owning/routing-important files, but do not summarize every file. File references must include extensions. Prefer `File.ext`; add a short path only when needed to disambiguate or when that path itself carries useful routing information.

Usually reject:

- transient task state, TODO progress, session summaries, or changelog history;
- generic architecture prose or rationale that does not help locate code;
- style rules obvious from surrounding code or enforceable by tools;
- test results, debugging traces, failed experiments, and raw tool output;
- code snippets or facts cheaply visible after opening an already-known target file;
- boilerplate DTOs, exceptions, generated files, trivial adapters, or files whose names already make their role obvious unless they are useful routing targets;
- exhaustive directory trees, every class/function, every caller/reference, or one entry per file by default.

For every candidate line ask: **What future repository search or read is this expected to prevent?** If there is no concrete answer, omit it.

### Admission scoring

Use this internal score when value is unclear. Do not write scores into `.project-map.md`.

- +3 directly routes a likely future task to source.
- +2 identifies non-obvious behavioral ownership.
- +2 can avoid tracing/searching multiple files.
- +1 identifies a non-obvious source of truth or architectural boundary.
- +1 is likely to recur across future work.
- -2 is obvious from the filename/directory name.
- -2 is recoverable with one cheap, narrow search.
- -3 is task-specific, transient, or historical.
- -3 substantially duplicates an existing entry.
- -4 needs verbose explanation to be useful.

Normally admit only candidates scoring **>= 2**. Prefer the highest-value compressed statement when several candidates encode the same routing knowledge.

## Learn from map misses

A **map miss** occurs when preflight cannot route the task sufficiently and fallback repository exploration is required to discover where relevant behavior lives.

During the primary task, do not stop to maintain the map. At end-of-turn reconciliation, for each meaningful fallback sequence ask:

1. What navigation question was the fallback trying to answer?
2. Did the map lack a route, ownership fact, flow, invariant, or source-of-truth pointer?
3. What is the smallest verified entry that would likely have avoided the same fallback next time?
4. Does that entry pass the admission policy and score?

If yes, include it in the end-of-turn rewrite. Do not record the search transcript or every discovered file.

Classify misses mentally when useful:

- **Route miss:** concept/task language did not point to the right source.
- **Ownership miss:** area was known but behavior-owning file was unclear.
- **Flow miss:** one file was known but important cross-file traversal still had to be rediscovered.
- **Stale-map miss:** an existing route/ownership/flow no longer matched source.
- **Novel exploration:** genuinely new knowledge with little expected reuse; usually do not store it.

The goal is for repeated work to pay progressively less repository-rediscovery cost.

## Compression by ownership

Prefer dense behavioral ownership over multiple descriptive facts.

Collapse facts such as:

```text
AuthenticationService.java handles login
AuthenticationService.java handles logout
AuthenticationService.java coordinates refresh tokens
```

into:

```text
`AuthenticationService.java` — login/logout/refresh orchestration
```

Rules:

- Group closely related responsibilities owned by the same file into one terse line.
- Keep distinctions only when they route future tasks differently.
- Prefer `File.ext — ownership` over sentences explaining implementation. If duplicate filenames make that ambiguous, use the shortest disambiguating path, e.g. `authentication/TokenService.java`, not the full physical path by default.
- Prefer one route to a behavior-owning file over lists of adjacent files.
- Keep a flow only when its sequence itself prevents future tracing.
- If a route and ownership line duplicate each other, keep both only when the route adds useful user-language aliases or traversal order.

Compression must preserve retrieval value, not prose completeness.

## Mandatory end-of-turn reconciliation and rewrite

After the user's requested repository work for the current prompt is complete, but before sending the final response, reconcile `.project-map.md` for that turn whenever repository source was inspected, searched, analyzed, or modified.

This is maintenance **after the work**, never a prerequisite that interrupts the work.

Perform a whole-map logical rewrite using the existing map plus all durable repository evidence learned during the completed turn, regardless of feature/task boundary:

1. Incorporate high-value durable routes, ownership, flows, invariants, and source-of-truth facts learned anywhere in the repository this turn.
2. Incorporate useful map-miss lessons.
3. Correct or remove entries contradicted by source inspected this turn.
4. Reconcile moves, renames, splits, merges, and responsibility changes caused or discovered this turn.
5. Merge duplicate/overlapping entries, especially facts that can become one ownership statement.
6. Remove low-value entries that no longer pass admission scoring.
7. Compress wording aggressively while preserving routing value, including shortening file paths to the minimum unambiguous form.
8. Enforce the size budget; prune toward <= 8 KiB and never exceed 12 KiB without explicit user preference.
9. Rewrite `.project-map.md` with the reconciled representation. If reconciliation produces byte-for-byte equivalent content, do not force a meaningless no-op write.

Do not perform a repository-wide validation scan at end of turn. Reconcile only from the existing map and source/search/change evidence already encountered while doing the requested work. Untouched entries remain unless current evidence contradicts them.

For repository-working prompts, perform this reconciliation on every response, not only when an entire feature is complete. Analysis-only prompts, repository questions, code review, explicitly requested file analysis, debugging, and implementation all count when repository source was actually inspected/searched/analyzed/modified.

If the prompt did not inspect, search, analyze, or modify repository source, no map reconciliation is required.

## File format

Use only useful sections; omit empty ones.

```markdown
# Project Map

> Navigation cache. Source files are authoritative.

## Project
<one sentence: what this repository is>

## Areas
- `<path-or-directory>/` — <responsibility>; start: `<EntryFile.ext>`

## Ownership
<area>/
- `<BehaviorOwner.ext>` — <owned behavior/responsibility>
- `<OtherOwner.ext>` — <owned behavior/responsibility>

## Routes
- <task/concept> -> `<FirstFile.ext>` -> `<NextFile.ext>`

## Flows
- <flow>: `<A.ext>` -> `<B.ext>` -> `<C.ext>`

## Invariants
- <non-obvious boundary that changes where code should be read/changed>
```

Keep entries terse, concrete, and optimized for future navigation rather than human-facing explanation.
