# Target Runtime Memory Ownership Audit

Date: 2026-10-15
Baseline commit: `d273232` (`decouple memory policy from compiler`)

Remediation status: **P0 String ownership resolved after the baseline audit.** Eido String target backing is now Storage-owned hidden language-runtime state; native text is copied at ABI boundaries; pure String computation is covered under Nim `--mm:none`.

Remediation validation used targeted suites only (not the full suite): String feature execution, String optional presence, `Storage<String>`, native function/class-method boundaries, managed GC runtime, module loading, Nim emission, compiler architecture, and compiler pipeline. The pipeline includes a manual-memory + Nim `--mm:none` String test and a native String-result copy test.

## Purpose

This audit verifies the project invariant that actual Eido target-program memory ownership must be implemented by Eido memory policy over `Storage`, while backend ABI/register/layout mechanics may remain backend-specific.

The audit is intentionally deeper than a normal code review. It covers generated target Nim, native backend support, hidden Eido memory runtime code, class/interface representation, `String`, `copy`, error paths, class-owned state, Storage escape hatches, and implicit stack use.

## Executive conclusion

The core memory architecture is substantially correct. Managed object payloads, GC headers, heap bookkeeping, roots, runtime type metadata, interface boxes, arenas, and class-owned source state are all routed through Eido code and `Storage`.

There is **no general local/parameter/result ownership problem**. Primitive values, object identities, Storage descriptors, and most optional values are inline/register/ABI representations. A backend may spill them to a machine stack slot, but that does not create an independent logical memory owner.

The original audit found two normal-success-path Eido-visible ownership gaps. **String has since been remediated.** The remaining normal-success-path gap is class graph-copy memoization: generated `copy` support still uses `seq[tuple[source, target]]`, which grows through the Nim memory manager.

A separate gap remains on exceptional paths: Storage validation, contracts, and optional unwrap failures construct Nim exception objects. This is not ordinary successful-program state, but it prevents complete target-runtime memory-manager independence.
## Audit boundary

This report distinguishes three kinds of memory:

1. **Eido-visible owned memory** — storage whose lifetime belongs to an Eido value/runtime structure. This must ultimately be owned through `Storage`.
2. **Backend representation memory** — registers, ABI argument/result locations, compiler spills, stack frames, raw function pointers, and static constants. These are machine implementation details rather than independent Eido allocation policy.
3. **Foreign/platform-internal memory** — OS/Nim-library buffering internal to a native call. This is outside Eido ownership unless a value backed by that memory crosses back into Eido.

Compiler/build-machine allocations are excluded. For example, the compiler's own `seq`, `Table`, parsed ASTs, and compile-time phase snapshots are not target-program memory.

## Method

The audit statically traced:

- the active `program_emitter.nim` import graph;
- generated type spellings and runtime helper bodies;
- all target-side `seq`, `ref object`, closure, `string`, `Option`, pointer, allocation, deallocation, exception, and output constructs;
- `stdlib/native/nim/eido_storage.nim` and `eido_native.nim`;
- the hidden Eido managed-memory runtime;
- Storage ownership/provenance analysis and address reconstruction APIs;
- manual-vs-GC compilation guards;
- existing `--mm:none` boundaries.

No full Eido build/test suite was run as part of this audit; conclusions are based on source-level ownership tracing.
## Ownership matrix

| Category | Current target representation | Actual dynamic owner | Status | Action |
|---|---|---|---|---|
| `Bool`/numeric/`Char` locals, params, results | Nim scalar | none beyond ABI/stack | compliant | none |
| Class/interface local identity | `int64` payload address | object runtime, not local handle | compliant | none |
| Primitive optional | `Option[T]` | inline value | compliant | none |
| `String` / `String?` | opaque `int64` handle / inline `Option[int64]` | hidden Eido `StringRuntime` -> `Storage<Byte>` | **compliant (remediated)** | none for ownership; future lifetime optimization optional |
| Class payload | raw payload addressed by identity | Eido selected memory policy -> Storage | compliant | none |
| Interface box payload | runtime-acquired payload | Eido selected memory policy -> Storage | compliant | none |
| GC object header/back-pointer | raw Storage bytes/views | Eido GC -> Storage | compliant | none |
| Managed heap backing | `Storage<Byte>` | Eido `ManagedHeapAllocator` -> Storage | compliant | none |
| Live identity registry | `Storage<Int>` + `Storage<Bool>` | Eido runtime -> Storage | compliant | none |
| Runtime type/field registry | Storage arrays | Eido runtime -> Storage | compliant | none |
| Class-owned source field | one-slot `EidoStorage[T]` | Storage | compliant |
| Storage descriptor | inline pointer/counters/flags | no backing allocation by descriptor itself | compliant | none |
| Arena backing | `Storage<T>` root + borrowed slices | Eido Arena -> Storage | compliant | none |
| Graph-copy memo | Nim `seq[tuple[source,target]]` | Nim memory manager | **gap** | move scratch state to Storage/Eido |
| Contracts/Storage failures | Nim exception object | Nim runtime | **gap, exceptional path** | non-Nim/Eido trap model |
| `Process.argument()` result | foreign Nim `string` copied immediately to Eido String handle | Eido `StringRuntime` -> Storage after ABI bridge | **compliant (remediated)** | none |
| Console internal buffers | native/Nim/OS I/O implementation | platform | boundary-acceptable | no Eido-visible ownership |
| Generated main result printing | Nim `echo` | backend/platform formatting | temporary dependency | remove temporary harness |
| Runtime interface method pointer | `.nimcall` proc pointer | inline code pointer | compliant | none |
| Machine call stack / spills | backend/CPU stack | execution environment | not Eido allocation policy | no AutomaticRegion required now |
| GC recursive traversal stack | machine call stack | execution environment | not ownership gap; resource risk | optional future iterative traversal |
## Finding F1 — String ownership violation **resolved**

**Original priority: P0 — remediated after the baseline audit.**

The original evidence was valid at baseline: Eido `String` mapped to Nim `string`, concatenation used Nim `&`, `Storage<String>` stored a Nim-managed descriptor, native String results crossed directly into Eido, and GC metadata carried String-specific cleanup kinds.

The remediation replaced that representation end-to-end:

- target `String` now lowers to an opaque `int64` handle;
- hidden `eido.stdlib.text/string_runtime.eido` owns immutable UTF-8 bytes through `Storage<Byte>`;
- literals copy fixed UTF-8 bytes directly into Eido String storage;
- concatenation and equality execute through ordinary hidden Eido runtime methods;
- `Storage<String>` stores only the handle, not a backend-managed text buffer;
- native String results are copied into Eido storage immediately at the ABI boundary, while outgoing native calls receive only temporary foreign strings;
- String-specific GC cleanup metadata and payload cleanup were deleted;
- String allocations use a simple program-lifetime linked ownership policy and are released by String-runtime shutdown;
- a targeted compiler-pipeline regression executes String allocation, concatenation, equality, and shutdown under Nim `--mm:none`.

This closes the broad normal-success-path String ownership gap. Future String work such as interning, reference counting, or earlier reclamation is an optimization/lifetime-policy question, not required to restore the Storage ownership invariant.

## Finding F2 — graph-copy memo state bypasses Storage

**Priority: P1**

Evidence: `compiler/src/backend/nim/emitter/class_copy_emitter.nim` emits a per-class field of type `seq[tuple[source, target]]` inside the generated copy context, and appends entries with `.add(...)`.

This allocation occurs at target runtime when `copy` traverses a class graph. The copied object payloads themselves use normal Eido object allocation, but the memoization structure that preserves sharing/cycles is owned by Nim.

This is a real normal-success-path ownership violation, although it is narrower than String because it appears only when class graph `copy` executes.

### Required end state

Copy bookkeeping should use Storage-backed scratch state, preferably behind an ordinary Eido/runtime abstraction. The compiler may continue generating graph-copy semantics, but it should not select Nim `seq` as the storage owner.

A minimal implementation can use growable Storage arrays of source/target identity pairs. A more general future scratch-map abstraction is reasonable only if another feature also needs it.

## Finding F3 — failure/trap handling still depends on Nim-managed exceptions

**Priority: P1 for whole-program runtime independence; P2 for ordinary successful execution**

Target-generated failures include contract violations and absent optional identity unwraps. `eido_storage.nim` also raises Nim exception objects for bounds, liveness, alignment, ownership, and allocation failures.

These paths are not ordinary Eido value ownership, but they still invoke Nim runtime allocation/exception machinery and therefore block a strict claim that the target runtime is independent of the Nim memory manager on every path.

### Required end state

Define a backend-neutral Eido trap/panic/failure boundary. The hosted backend can ultimately lower that boundary to a non-owning/native termination mechanism or an Eido-owned error representation. Do not redesign this as general exception syntax unless the language actually wants exceptions.
## Finding F4 — bootstrap `ref object` / closure representations are latent, not current target owners

**Priority: P3 cleanup / future-guardrail**

`nominal_type_emitter.nim` still contains a no-object-runtime fallback that represents classes/interfaces as Nim `ref object`, and bootstrap interface methods use Nim closures. `class_emitter.nim` also still contains an old `ref object` emitter, but it is not imported by the active `program_emitter.nim` path.

For current ordinary target programs this does **not** constitute a live ownership violation:

- GC mode generates object metadata whenever ordinary identity-bearing classes or object construction require runtime representation.
- manual mode rejects identity-bearing class declarations and class construction before code generation.
- the empty-plan path is used by compiler-standard build-machine Eido phase compilation and by declarations that do not require object identity.

However, these fallbacks are dangerous architectural fossils. If manual object support or another strategy grows without tightening this path, Nim `ref object`/closure allocation could silently re-enter target semantics.

Recommendation: remove the unused `class_emitter.nim` and explicitly constrain or rename the bootstrap nominal path before adding another object strategy.

## Finding F5 — `Storage.adoptAddress` is an intentionally unsafe ownership reconstruction capability

**Priority: P2 safety, not an ownership-architecture violation**

`Storage<Byte>.adoptAddress(address, ...)` reconstructs an owning Storage descriptor from an integer address. The native implementation will eventually call `dealloc` on that address when released.

The current API contract says the address must originate from an owning Storage allocation, and the managed heap follows that rule. The compiler does not currently prove this provenance, so ordinary source can forge an integer address and claim ownership.

This does not create a second allocator—the resulting owner is still Storage—but it weakens memory safety and can make Storage free memory it never acquired.

Recommendation: when borrow/lifetime/provenance analysis matures, track ownership tokens/addresses strongly enough to prove `adoptAddress` provenance, or restrict this operation to trusted/runtime code if general source does not need it.
## Finding F6 — class-owned Storage slots are compliant but intentionally process-lifetime

**Priority: P3 lifecycle hygiene**

Every class-owned source value is represented by a one-slot `EidoStorage[T]`, including runtime bookkeeping fields. This satisfies the ownership invariant: the backing allocation is obtained through Storage.

Those outer one-slot capabilities are not generally released before process exit. Runtime shutdown releases the GC heap and the inner registry Storage arrays, but the class-owned wrapper slots themselves remain process-lifetime allocations.

This is not a policy violation and matches static/class lifetime semantics. It is worth documenting because leak detectors may report these allocations even though they are deliberately rooted until process termination.

If deterministic teardown becomes a requirement for embedded hosts, reusable runtimes, or in-process Eido instances, add explicit class-state teardown. It is not necessary for the current executable process model.

## Finding F7 — the temporary main harness and native I/O still depend on backend runtime services

**Priority: P2/P3**

`program_emitter.nim` prints value-returning `main` results with Nim `echo`. `Console` delegates to Nim/std I/O, and `Process.argument()` delegates to `paramStr`.

OS/Nim I/O buffers internal to a native call are considered platform-owned and do not violate Eido ownership as long as they remain internal. `Process.argument()` now copies its temporary native String result into Eido-owned String storage before Eido code observes it, so native text ownership no longer crosses the ABI silently.

The generated `echo` harness is explicitly temporary and should disappear in favor of normal stdlib/process semantics. Its removal also reduces dependence on backend formatting/runtime allocation.

## Finding F8 — recursive traversal consumes machine stack but does not create a second memory owner

**Priority: P3 robustness**

`ManagedGcRuntime.mark` recursively traverses object graphs, and generated class graph copy is recursive as well. Their call frames use the machine/Nim stack.

This is not equivalent to heap allocation and does not violate the Storage ownership rule. The same is true for ordinary function locals, parameters, return slots, compiler spills, and ABI registers.

For deeply nested graphs or constrained embedded targets, iterative traversal with a Storage-backed worklist may eventually be preferable for bounded stack usage. That is a resource/determinism improvement, not a prerequisite for architectural correctness.
## Why an AutomaticRegion is not currently necessary

The audit found no current language value category that requires a new generic automatic-region allocator merely because it is a local, parameter, result, or temporary.

- Primitive values are inline machine values.
- Class/interface locals are identity handles; their payload ownership is elsewhere.
- `Storage<T>` locals are descriptors; backing ownership is already represented by Storage.
- Primitive optionals are inline `Option[T]` representations.
- Temporary class/interface objects already acquire payload storage through the selected Eido object policy.

A backend may place any of those values in registers or stack slots. That is analogous to register allocation/spilling and is not an Eido-level ownership decision.

An AutomaticRegion should be introduced only when Eido gains a value whose actual backing storage has automatic scope lifetime and cannot already be represented without a separate allocation. Examples could include future large inline aggregates or an explicitly chosen stack/region object policy. No such requirement exists today.

## Confirmed compliant ownership paths

### Managed class objects

Construction semantics remain compiler-owned, but physical storage acquisition crosses the generic policy-selected object-acquisition event. The current GC policy routes this to `ManagedGcRuntime.allocate`, which obtains backing from `ManagedHeapAllocator`, which uses `Storage<Byte>.allocateRaw`.

### Interface boxes

Runtime interface boxes use the same policy-selected object acquisition and are payload-address identities. Receiver identities and method pointers are fields in Storage-backed payloads; `.nimcall` method pointers do not allocate closure environments.

### GC metadata and roots

`MemoryValueRegistry` and `MemoryTypeRegistry` store all mutable tables in Storage arrays. Resize operations allocate replacement Storage, copy values, then release old Storage. No native root chain or native type registry remains.

### Class-owned state

Source class-owned values live in one-slot Storage backing. Backend globals hold Storage descriptors and generic value-slot IDs only; they are not parallel source-value owners.
### Storage substrate

`EidoStorage[T]` is an allocation-free descriptor. `eidoStorageAllocateRaw` is the single hosted owned-backing allocation path and uses `alloc0`; `eidoStorageRelease` returns owned backing with `dealloc`. Typed allocate/view/slice operations compose or reinterpret that descriptor rather than acquiring a second hidden region.

Using `alloc0`/`dealloc` here is architecturally allowed: this is the physical backend implementation of Storage itself, not a competing target memory policy.

### Optional values

Optional class/interface identity uses the nullable identity handle directly. Primitive optionals use inline `Option[T]`. `String?` now uses inline `Option[int64]`; the optional wrapper contains only the Eido String handle while UTF-8 backing remains Storage-owned by `StringRuntime`. None of these optional representations introduce a separate allocator.

### Static metadata and code pointers

Generated type IDs, layout constants, function/method pointers, and static string literals/code are static representation data. They do not constitute dynamically owned Eido memory.

## Adjacent risks that are not ownership violations

### Target layout is currently host-Nim layout

`target_storage_layout.nim` derives `sizeof`/`alignof` from the current Nim backend/host representation. The file explicitly notes that this must become target-parameterized for future cross-target builds. This is a portability/layout issue, not a second memory owner.

### Raw Storage addresses are intentionally low level

`address`, `fromAddress`, and `adoptAddress` expose pointer-like capability through `Int`. This is useful for runtimes, embedded memory, and FFI, but it means future safety work must distinguish trusted low-level use from ordinary safe code.

### GC mark recursion is unbounded by policy metadata

Recursive mark does not allocate heap memory outside Storage, but graph depth controls machine stack use. Embedded/deterministic targets may want an iterative Storage-backed worklist later.

### String-specific cleanup metadata — resolved

The baseline audit found String-specific cleanup kinds in `memory_metadata_emitter.nim` and matching GC payload cleanup. Those paths have been removed. Object metadata now reports only generic field layout/identity facts; String fields are ordinary opaque handles whose backing lifetime is owned independently by `StringRuntime`.
## Recommended migration order

### P0 — replace Nim-backed `String` — **completed**

All ownership acceptance criteria from the baseline audit are now satisfied:

- Eido `String` target storage is an opaque `int64` handle, not Nim `string`;
- dynamic UTF-8 bytes are acquired through hidden Eido `StringRuntime` over `Storage<Byte>`;
- concatenation and content equality do not use Nim String allocation;
- `Process.argument()`/native String results are copied into Eido storage before returning to Eido code;
- class sweep no longer carries String-specific cleanup kinds;
- `Storage<String>` contains only the handle and hides no Nim-managed character buffer;
- pure String operations execute under Nim `--mm:none`.

The current program-lifetime reclamation policy is intentionally simple and may be optimized later without changing the ownership result.

### P1 — move graph-copy memoization to Storage/Eido

Acceptance criteria:

- generated target code contains no `seq[tuple[source,target]]` copy tables;
- cyclic/shared graph copy still preserves identity topology;
- scratch backing is explicitly released or owned by an Eido lifetime policy.

### P1/P2 — replace target Nim exception allocation with a trap/failure boundary

Acceptance criteria:

- contract, optional unwrap, bounds, liveness, alignment, and ownership failures do not require Nim exception objects;
- successful behavior remains unchanged;
- the design does not accidentally introduce source-level exception semantics.

### P2 — tighten Storage address provenance

Prove or restrict `adoptAddress` ownership reconstruction. This is primarily a safety task and can follow the normal-path ownership fixes.

### P3 — remove/isolate bootstrap ownership fossils

Delete the unused `class_emitter.nim` and ensure `ref object` / closure fallback code cannot become an ordinary target object representation when new memory strategies are added.

## Architectural guardrails to keep

1. **Do not equate a local variable with an allocation.** Registers, stack slots, ABI parameters/results, and identity handles are backend representation.
2. **Any Eido-visible dynamic backing region must have an Eido/Storage owner.** A backend container must not become the hidden owner merely because it is convenient.
3. **Native/platform code may use foreign internals, but foreign ownership must not silently cross the ABI.** Values returned into Eido need an Eido-owned representation.
4. **Storage remains the only physical owned-allocation substrate for the hosted backend.** Higher policies orchestrate Storage; they do not introduce parallel native allocators.
5. **Future memory strategies must not reactivate bootstrap `ref object`/closure allocation.** Strategy absence must never silently mean “let Nim own the object.”
6. **Managed backend types stored inside Storage require explicit scrutiny.** String remediation demonstrates the rule: a Storage slot is sufficient only when the value inside it does not hide independently backend-owned dynamic backing.

## Final verdict

The memory redesign is not missing a large automatic/local-memory layer. The major work already completed—object payloads, GC state, roots, metadata, interfaces, class-owned values, heap allocation, and arenas—is genuinely Storage-centered.

String P0 is now closed. The remaining architecture debt is narrow and identifiable:

- **P1:** Nim-owned graph-copy memo `seq`;
- **P1/P2:** Nim exception/trap allocation on failure paths;
- **P2:** Storage address ownership provenance safety;
- **P3:** bootstrap `ref object`/closure cleanup and recursive-stack robustness.

With String backing migrated, the only known normal-success-path Eido-visible dynamic ownership bypass is graph-copy scratch memoization. After copy scratch state and target failure handling are migrated, a strict whole-target ownership claim will be much more defensible. Further memory work should then be driven by new language requirements (large inline values, embedded deterministic stack policy, new allocators, concurrency, etc.), not by a presumed need to route every local variable through Storage.
