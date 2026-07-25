# Feature Specification: Engine Lifecycle, Test-and-Handoff, and Adaptive Sync

**Feature Branch**: `002-clickup-lifecycle`

**Created**: 2026-07-11

**Status**: Draft

**Input**: User description: "Specify all of the lifecycle backlog (§0–§5) as one feature: the
post-implement test-everything + handoff + close-out gate, the full status lifecycle advancing per
Spec Kit command, human-testing handoff, a manual/light tracking mode, agent-designed per-project
rules, and linking GitHub commits/PRs to tracker items."

> This spec supersedes the original `BACKLOG.md` that formerly lived in this directory; the
> backlog's six tracks (§0–§5) are fully captured as user stories below (US1–US7) and it has been
> removed. Section references like "§0"/"§5" throughout refer to those original backlog tracks.
> Two further user stories were added during design (US8 `/speckit-engine-verify`, US9 consolidating
> snackbyte's lifecycle extensions into the engine) — see the Clarifications section.

**Engine vs. plug — how to read this spec.** This feature specifies **snackbyte-speckit-engine**:
a generic, tracker-agnostic Spec Kit lifecycle engine that broadcasts each lifecycle event to zero
or more swappable tracker **plugs**. Almost everything below is **engine** behavior (deriving
status, the per-command lifecycle, close-out, handoff, human-vs-derived status ownership, manual
items, project-rule design) and is written tracker-agnostically. Where a requirement names ClickUp
concretely (the MCP transport, `.clickup-sync.json`, ClickUp status names), that is **the ClickUp
plug's implementation** of a generic engine capability — ClickUp is the first plug, not the
subject. A second plug (Linear, a local file, …) would satisfy the same requirements its own way.

This feature builds on the shipped **ClickUp plug** (`001-clickup-sync`: one-way, MCP-only,
idempotent, scaffolding-only) without revisiting its core mapping (feature = tracker item, user
story = subtask, `tasks.md` line = checklist item). It generalizes that plug's proven model into
the engine and extends it along the tracks drawn from this feature's original backlog (US1–US7),
plus two design-time additions (US8 `/speckit-engine-verify`, US9 extension consolidation). Each user
story is a separately deliverable slice; the priorities below reflect the backlog's own ordering
(§0 and the lifecycle first, enrichment later) with the two P1 additions folded in.

## Clarifications

### Session 2026-07-11

- Q: How is the close-out ceremony (US2) invoked? → A: A distinct user-invoked command
  (`/speckit-engine-close`), run when the human is ready — not tied to a lifecycle hook.
- Q: Where does the test gate run, and what happens on a red gate? → A: The gate runs inside the
  new `/speckit-engine-verify` command (after implement + converge), not in the `after_implement` chain. A
  red gate stops verify and blocks the `in-review` transition; the card stays at `in-development`
  until the gate is green. (This refined an earlier "hard-stop the after_implement chain" idea once
  `/speckit-engine-verify` became the home of the gate.)
- Q: Which mechanism links commit/PR provenance onto the card (US6)? → A: Both — ship Option A
  (MCP-pushed by our extension, self-contained) now; leave Option B (ClickUp's native GitHub
  integration) as a documented opt-in for teams that connect GitHub. Refinement: A and B are
  mutually exclusive per project — when B is opted in, A MUST stand down so provenance is not
  pushed redundantly (no duplicate commit links on the card).
- Q: How is the human-review handoff handled (US4)? → A: The AI is the sole tracker writer; humans
  never need to touch the tracker. Human decisions (sign-off, "couldn't test X") are given to the
  flow and the AI reflects them onto the card. (This superseded an earlier "protect a human-owned
  status subset" idea — there is no human write-path in the normal flow to protect.)
- Q: How does the sync distinguish a manual item from a spec-driven feature-card (US5)? → A:
  Ownership by manifest presence — the sync only ever touches cards recorded in a feature's
  `.clickup-sync.json` manifest (reusing the 001 mechanism). Manual items (and unrelated cards)
  are simply never in a manifest, so they are never touched. No new marker/tag/custom-field.
- Q: What is the expanded status model? → A: A six-state card lifecycle (`open` → `in-design` →
  `ready` → `in-development` → `in-review` → `done`), config-mapped to each project's real status
  names and degradable to a three-state floor. Every Spec Kit command syncs (writing artifacts is
  visible as work). Subtasks stay three-state (units of work). The AI is the sole tracker writer;
  humans signal via the flow (US4 reframed — see below).
- Q: How is `in-review` earned, and what runs between implement and review? → A: A new
  `/speckit-engine-verify` command (US8): implement → converge (always) → `/speckit-engine-verify` (recursive
  code review + full unit gate + automatable E2E) → only on pass does the card reach `in-review`.
  Then `/speckit-engine-close` handles sign-off → `done`. Verify and close are two distinct commands.
- Q: Should snackbyte's scattered Spec Kit extensions be consolidated here? → A: Yes (US9) — the
  five snackbyte-authored extensions (git-specify-branch, specify-review-loop, analyze-autofix,
  git-commit, clickup-sync) become command-modules of the one engine; the recursive-review module
  serves both spec and code targets. The upstream `agent-context` (spec-kit-core) is excluded.
  Migrating other repos onto the engine is follow-on work, out of scope here.
- Q: What about making the lifecycle lighter/configurable (models, verbosity, optional steps)? →
  A: Deferred to a separate backlog (`004-lifecycle-profiles`) — 002 defines the full, heaviest
  lifecycle first; profiles layer on top once it works.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Finish-the-job test gate and honest handoff (Priority: P1)

As a developer who just ran `/speckit-implement`, I want a single repeatable step that does
everything the AI can to verify the feature before it reaches me — run the unit gate, drive the
end-to-end path as far as is automatable, then produce an honest handoff of what was verified
versus what remains — so that "tested" means actually exercised, not asserted, and I only get
the genuinely-manual remainder.

> US1 defines the **test-and-handoff capability**; US8 (`/speckit-engine-verify`) is the **command that
> runs it** at the right lifecycle moment and, on success, earns the `in-review` state. They are
> the same gate viewed as capability (US1) vs. invocation + state transition (US8).

**Why this priority**: This is the backlog's §0 and is independent of ClickUp entirely — it can
ship first and delivers value on its own (a codified pre-handoff discipline) even if no other
track lands. It closes the gap where the lifecycle ends at `after_implement`, before manual
verification and close-out.

**Independent Test**: On a feature with a green unit suite, run the gate → it runs the check gate,
drives whatever E2E is automatable, and reports what was verified vs. what remains manual. On a
feature with a red gate, it fails loud and does not report a "verified" handoff.

**Acceptance Scenarios**:

1. **Given** a feature whose unit tests and project check gate pass, **When** the test gate runs,
   **Then** it records the gate as green with evidence (suite counts / gate output) and proceeds.
2. **Given** a feature whose check gate is red, **When** the test gate runs, **Then** it stops
   with the failure surfaced and does NOT produce a "verified" handoff.
3. **Given** a feature with automatable E2E, **When** the test gate runs, **Then** it drives that
   E2E and folds the result into the report; whatever it cannot exercise it records with a reason
   rather than silently skipping.
4. **Given** the automated phases complete, **When** the handoff is produced, **Then** it lists
   what the feature does and where it lives, what was verified automatically (with evidence),
   what remains manual and why, and the exact manual steps left for the human.

---

### User Story 2 - Close-out ceremony: sign-off, final sync, commit (Priority: P1)

As a developer whose feature has an irreducible manual verification slice, I want a terminal
close-out step that surfaces the remaining manual tasks for my explicit sign-off, marks them done
in `tasks.md` only once I sign off, runs the final sync so the tracker card reaches done, and
commits the close-out edits — so that "commit vs. sync vs. close" is one ordered ceremony instead
of three decoupled acts a human has to remember to run in order.

**Why this priority**: This is §0's Phase C — the missing terminal step. It pairs with US1 (they
share the same lifecycle moment) and encodes the exact hand-run steps that 001's own dogfood
required. Without it a feature is never truly "done" in the flow.

**Independent Test**: On a feature with unchecked manual tasks in `tasks.md`, run close-out → it
lists those tasks and waits; on sign-off it checks them in `tasks.md`, runs the final sync
(card → done), and commits the edits. It never silently checks a manual task, and the sync step
itself never commits (constitution I / 001 FR-019).

**Acceptance Scenarios**:

1. **Given** a feature with unchecked human-in-the-loop tasks, **When** close-out runs, **Then**
   it surfaces exactly those tasks and waits for explicit sign-off — it never auto-checks them.
2. **Given** the human signs off, **When** close-out continues, **Then** it marks those tasks done
   in `tasks.md`, runs the final one-way sync (card + subtasks → done/shipped), and creates a
   fresh commit of the close-out edits.
3. **Given** close-out runs, **When** it performs the sync, **Then** the sync makes no commit
   itself; the commit is a distinct close-out step (the implement-time git-commit hook already
   fired before these edits existed).
4. **Given** non-manual tasks are still incomplete, **When** close-out runs, **Then** it refuses
   to close and reports what remains.

---

### User Story 3 - Every command advances the card through the artifact lifecycle (Priority: P1)

As a stakeholder watching a feature's card, I want it to move on **every** Spec Kit command — not
just when code is written — so the board shows that **writing the artifacts (spec, plan, tasks)
is work**, not just implementation. Specifying a feature is progress; the card should say so. The
whole point: when the AI fires off a Spec Kit command, something happens, and I want to see that
reflected on the card right then.

**Why this priority**: This is §1 and is the heart of the engine. 001 derives only
not-started / in-progress / done and only re-syncs at two late hooks, so a feature can be
specified, clarified, and planned while the card looks idle — hiding real work. This makes **every
command update the card**, so the artifact phase is visible as work.

**The lifecycle — six logical states.** The card advances through an ordered set of at most six
logical states, each a real transition a watcher can see:

| # | Logical state | Enters when | Meaning |
|---|---|---|---|
| 1 | `open` | the feature exists (first command / provision) | task made, nothing started |
| 2 | `in-design` | `after_specify` (also clarify, plan) | artifacts being written |
| 3 | `ready` | `after_tasks` / `after_analyze` | designing done, code not started |
| 4 | `in-development` | `after_implement` | code being written |
| 5 | `in-review` | `/speckit-engine-verify` passes (after converge) | AI reviewed + tested everything it can; awaits human sign-off |
| 6 | `done` | `/speckit-engine-close` + sign-off | complete |

**Config-mapped names, fall back to 3.** These six are *logical* states; each project maps them
onto its list's **actual** status names in config (my "in-design" may be another list's "scoping").
A list that doesn't have six distinct statuses falls back to the three basic ones (not-started /
in-progress / done), mapping each logical state to the nearest available one.

**Independent Test**: Run each lifecycle command in turn and observe the card advance open →
in-design → ready → in-development → in-review; a status-only change on unchanged content makes
zero content writes. On a list configured with only three statuses, the six logical states
collapse onto the three without error.

**Acceptance Scenarios**:

1. **Given** the six logical states are mapped in config, **When** each Spec Kit command runs
   (specify → clarify → plan → tasks → analyze → implement → converge), **Then** the card is
   re-synced on **every** command and its status is set to the logical state that command maps to,
   advancing whenever a command crosses into a new state.
2. **Given** the status changed but no content changed, **When** the per-command sync runs,
   **Then** it writes the status and nothing else (no duplicate content writes; constitution III).
3. **Given** a list configured with fewer than six statuses (down to three), **When** a logical
   state has no exact mapping, **Then** it collapses to the nearest configured status and the sync
   reports the degradation rather than failing.
4. **Given** the feature has just been provisioned and no command has run yet, **When** the card
   is created, **Then** it starts in `open` — so the `open → in-design` transition at
   `/speckit-specify` is itself visible as "design work started."

---

### User Story 4 - The human-review handoff happens in the flow, not on the board (Priority: P2)

As a developer, I never want to *have* to touch the tracker — the AI owns every write to the board,
and my decisions (sign-off, "I tested everything" vs. "here's what I couldn't test") are given to
the **flow** (at close-out, in the terminal), and the AI reflects them onto the card. The card is a
read-only mirror I can watch; it is not something I drive.

**Why this priority**: This is §2, and it resolves the correctness constraint 001 deferred — but
in a simpler way than "protect human-set statuses." Because the AI is the *only* writer, there is
no competing human write-path to reconcile in the normal flow. The card reaches `in-review` (state
5) only when the AI has done everything it can — `/speckit-engine-verify` (US8) has passed — and rests
there; when the human returns and runs close-out, the AI advances it to `done` on sign-off.

**Independent Test**: Drive a feature through `/speckit-engine-verify` → the AI sets the card to
`in-review` and leaves it (no human tracker action needed); the card visibly waits. Run close-out
and sign off in the flow → the AI advances the card to `done`. At no point is a human required to
edit the tracker.

**Acceptance Scenarios**:

1. **Given** the AI has taken the feature as far as it can (`/speckit-engine-verify` passed), **When** the
   sync runs, **Then** the AI sets the card to `in-review` and it rests there — no human tracker
   action is needed to reach or hold that state.
2. **Given** the human returns and runs close-out, **When** they sign off in the flow, **Then** the
   AI writes `done` to the card — the human never touches the tracker to advance it.

---

### User Story 5 - Manual / light tracking mode (Priority: P2)

As someone doing work outside the full Spec Kit pipeline, I want a lighter tracking mode for a
hand-maintained item — one with no backing `tasks.md` to derive status from — so I can track
one-off work on the same board without the sync clobbering my manually-set status.

**Why this priority**: This is §3. It generalizes the extension beyond spec-driven features. A
manual item is safe by construction — it's simply never recorded in a feature manifest, so the
sync never touches it (FR-022).

**Independent Test**: Create a manually-tracked item; the sync recognizes it as manual (no
derivation), never overwrites its human-set status or hand-maintained content, and tells it apart
from spec-driven feature-cards in the shared list.

**Acceptance Scenarios**:

1. **Given** a manually-tracked item with no backing `tasks.md`, **When** the sync runs, **Then**
   it does not derive or overwrite the item's status or content.
2. **Given** a shared list holding both spec-driven and manual items, **When** the sync runs,
   **Then** it correctly distinguishes the two and only reconciles the spec-driven cards it owns.

---

### User Story 6 - Card shows the code that shipped it (Priority: P3)

As a reviewer looking at a ClickUp card, I want to see which commits (and, where available, PRs)
implemented the feature, so the card closes the loop between the tracker and the code — not just
"what/why" from the spec but "what actually shipped it."

**Why this priority**: This is §5 and is pure enrichment on top of a working card. It stays
one-way (repo → ClickUp) and is the lowest priority because the card is fully useful without it.

**Independent Test**: After a feature's commits exist, the sync (or close-out) attaches the
feature's commit provenance to the card via MCP; re-running does not duplicate the links.

**Acceptance Scenarios**:

1. **Given** a feature with commits, **When** the provenance step runs, **Then** the card shows
   the feature's commits (as a comment, a body section, or task links per the chosen mechanism).
2. **Given** the provenance was already attached, **When** the step re-runs unchanged, **Then** it
   adds no duplicate links (idempotence; constitution III).

---

### User Story 7 - Agent-designed, project-specific ClickUp rules (Priority: P3)

As a team with our own ClickUp conventions, I want an agent step that inspects our real workspace
and proposes a tailored ruleset — which lifecycle states to use and how they map, whether phases
or user stories become tags vs. subtasks vs. lists, what the card body emphasizes, custom-field
usage — recorded as config the sync then honors, so the extension adapts to our board instead of
forcing our board to adapt to its one baked-in default.

**Why this priority**: This is §4 and is the most open-ended, highest-impact track (it can reshape
a team's board), so it is lowest priority and gated behind explicit approval. The baked-in 001
defaults remain the always-present fallback; this is opt-in enrichment.

**Independent Test**: Run the design step against a real workspace → it produces a proposed
ruleset for approval; on approval the ruleset is recorded as config and the next sync honors it;
with no ruleset the baked-in defaults are used unchanged.

**Acceptance Scenarios**:

1. **Given** a project with an existing ClickUp workflow, **When** the design step runs, **Then**
   it inspects the real space/list/statuses/custom-fields and proposes a ruleset for approval —
   it does not silently apply board-reshaping changes.
2. **Given** an approved ruleset recorded as config, **When** the sync runs, **Then** it honors
   the ruleset; **Given** no ruleset, **Then** the baked-in defaults are used unchanged.

---

### User Story 8 - `/speckit-engine-verify` earns the review state (Priority: P1)

As a developer, after implementation I want one command that makes the AI do **everything it can to
certify the work** — recursively review the code it wrote, then run the full unit gate and every
automatable end-to-end test — and only then mark the card `in-review`. So `in-review` means "the AI
verified all it could," not merely "converge finished." This is the earned handoff point.

**Why this priority**: This is the missing "last step before review" and it makes `in-review` an
honest signal. It concretizes the §0 test-gate (US1) into a specific command with a specific
trigger and a specific outcome (the state transition). Without it, the card could reach review with
un-reviewed, un-tested work.

**The sequence**: `/speckit-implement` → `after_implement` chain always runs `converge` (which may
append unbuilt work as tasks) → the developer runs **`/speckit-engine-verify`**, which: (a) recursively
reviews the implemented code + tests (the same recursive-review pattern as spec review, pointed at
code — see US9); (b) runs the full unit check gate, which MUST pass; (c) runs every automatable
E2E as far as the tooling allows (the US1 gate); (d) on success, marks the card `in-review`. On
failure at any step, it stops, reports, and does NOT advance to `in-review`.

**Independent Test**: On a feature whose implementation is complete and green, run `/speckit-engine-verify`
→ it reviews the code, runs the unit gate + automatable E2E, and advances the card to `in-review`.
On a feature with a failing gate or unreviewed issues, `/speckit-engine-verify` stops with the failure and
the card stays at `in-development` — it is never marked `in-review` over failing verification.

**Acceptance Scenarios**:

1. **Given** a completed implementation, **When** `/speckit-engine-verify` runs, **Then** it recursively
   reviews the code, runs the full unit gate and all automatable E2E, and — only if all pass —
   marks the card `in-review`.
2. **Given** the unit gate is red or the review surfaces an unresolved issue, **When**
   `/speckit-engine-verify` runs, **Then** it stops, reports, and leaves the card at `in-development` (never
   `in-review`).
3. **Given** `/speckit-engine-verify` passed, **When** the developer later runs close-out (US2), **Then**
   close-out proceeds from the verified `in-review` state to sign-off → `done`.

---

### User Story 9 - Consolidate snackbyte's lifecycle extensions into the engine (Priority: P1)

As the maintainer, I want snackbyte's own scattered Spec Kit extensions — currently duplicated
across many repos — consolidated into this one engine as command-modules, so the engine is the
single home for the lifecycle patterns instead of N one-off copies. The engine exposes all the
lifecycle commands plus the tracker-plug interface; a project installs the engine and gets the
whole spine.

**Why this priority**: The verify command (US8) reuses the recursive-review pattern that already
exists as the `specify-review-loop` extension — so consolidation is a prerequisite for building
US8 cleanly rather than duplicating the pattern. It also delivers the core engine promise: one
place for the lifecycle.

**Scope — the five snackbyte-authored extensions** become engine modules: `git-specify-branch`
(setup: clean tree + feature branch), `specify-review-loop` (recursive artifact review),
`analyze-autofix` (apply unambiguous artifact fixes), `git-commit` (checkpoint commit), and
`clickup-sync` (already the ClickUp plug here). The upstream `agent-context` extension (authored by
`spec-kit-core`, not snackbyte) is **excluded** — it stays a separately-installed community
extension the engine coexists with. Migrating other repos off their scattered copies onto the
engine is **follow-on work, out of scope** here (build the engine first; adoption later).

**One review module, two targets**: the consolidated recursive-review module reviews whatever
artifact it is pointed at — the **spec** (after specify, the existing behavior) or the **code +
tests** (inside `/speckit-engine-verify`, US8). One pattern, two invocation points; the review logic lives
once.

**Independent Test**: Install the engine into a clean repo → the full lifecycle spine is available
(setup → spec-review → analyze-autofix → commit-checkpoint → verify → close) from the one engine
extension, plus the tracker-plug interface. The five snackbyte modules behave as their standalone
predecessors did; `agent-context` is untouched and still installable alongside.

**Acceptance Scenarios**:

1. **Given** the engine is installed, **When** a project runs the Spec Kit lifecycle, **Then** the
   five consolidated snackbyte modules (branch-setup, spec/code review, analyze-autofix, commit
   checkpoint, ClickUp plug) are all available from the one engine, exposing the same behavior as
   the former standalone extensions.
2. **Given** the recursive-review module, **When** it is invoked after specify vs. inside
   `/speckit-engine-verify`, **Then** the same review pattern runs against the spec vs. the code/tests
   respectively — one implementation, two targets.
3. **Given** the upstream `agent-context` extension, **When** the engine is installed, **Then**
   `agent-context` is neither absorbed nor broken — it remains a separate community extension the
   engine coexists with.

---

### Edge Cases

- **Red gate at close-out**: close-out (`/speckit-engine-close`) re-runs the check gate first; if it is
  red, close-out refuses to proceed (no sign-off, no final sync, no commit) and surfaces the
  failure. It never closes over a red gate.
- **Converge adds work after verify**: `converge` runs in the `after_implement` chain and may
  append unbuilt tasks. Because `in-review` is only reachable through a passing `/speckit-engine-verify`
  (FR-034/035), any converge-added work is still subject to verify — a feature can't reach review
  with unbuilt work outstanding.
- **Manual item mistaken for spec-driven** (or vice versa) in a shared list — structurally
  prevented by FR-022: ownership is manifest presence, so a card not in any feature manifest is
  never touched regardless of appearance; the sync never re-scans or classifies list contents.
- **Commit vs. card ordering (US6)**: because the card is now created at provision (FR-013a),
  before any commit, its tracker ID exists early — so provenance (US6) and any commit-message
  convention can reference it. This resolves the old "commit predates the card" ordering snag.
- **Fewer statuses than the lifecycle needs**: a target list with a reduced status set (US3
  degradation).
- **Designed ruleset conflicts with the baked-in defaults or the constitution** (e.g. a proposed
  rule that would require two-way sync) — must be rejected, not honored (US7 vs. constitution I).

## Requirements *(mandatory)*

### Functional Requirements

**Test-and-handoff gate (US1)**

- **FR-001**: The system MUST provide a repeatable post-implement step that runs the project's
  full check gate (unit + any feature-specific `*.test.sh`) and records the result with evidence.
- **FR-002**: The system MUST drive the end-to-end path as far as is automatable — running whatever
  E2E the AI has control over — and MUST report what it could not exercise and why, rather than
  silently skipping.
- **FR-003**: The system MUST identify and clearly delimit the irreducible manual remainder, with
  a stated reason each item could not be automated.
- **FR-004**: The system MUST emit a handoff report listing: what the feature does and where it
  lives; what was verified automatically (with evidence) vs. what remains manual and why; any
  follow-ups/known gaps; and the exact manual steps left for the human.
- **FR-005**: A red check gate MUST prevent a "verified" handoff (fail-loud).
- **FR-006**: The test gate runs inside `/speckit-engine-verify` (US8), after `implement` and `converge`.
  A red gate MUST stop verify — it reports the failure and does NOT advance the card to `in-review`
  (see FR-034). The flow only proceeds once the gate passes.

**Close-out ceremony (US2)**

- **FR-007**: The system MUST provide a terminal close-out step that surfaces remaining
  manual/human-in-the-loop tasks and waits for explicit human sign-off — it MUST NOT auto-check
  them.
- **FR-008**: On sign-off, close-out MUST mark those tasks done in `tasks.md`, run the final
  one-way sync (card + subtasks → done/shipped), and commit the close-out edits as a distinct
  commit.
- **FR-009**: The sync invoked by close-out MUST NOT itself commit (constitution I / 001 FR-019);
  committing is a separate close-out step.
- **FR-010**: Close-out MUST refuse to close while non-manual tasks are incomplete.
- **FR-010a**: Close-out MUST re-run the phase-A check gate (FR-001) before it surfaces tasks for
  sign-off; a red gate MUST make close-out refuse to proceed (no sign-off, no final sync, no
  commit), surfacing the failure — close-out never closes over a red gate.
- **FR-011**: Close-out MUST be a distinct user-invoked command (`/speckit-engine-close`), run when the
  human is ready — NOT wired to an automatic lifecycle hook (it is human-paced: it waits for
  sign-off on manual verification, which no fixed hook moment can time).

**Per-command status lifecycle (US3)**

- **FR-012**: The feature-card MUST support the ordered lifecycle `open` → `in-design` → `ready` →
  `in-development` → `in-review` → `done` — six logical states, each a distinct, watcher-visible
  transition, falling back to three where a list can't express six (FR-015).
- **FR-013**: The engine MUST re-sync the card on **every** Spec Kit command — not a subset — and
  set its status to the logical state that command maps to. The command→state mapping is:
  `after_specify`/`after_clarify`/`after_plan` → `in-design`; `after_tasks`/`after_analyze` →
  `ready`; `after_implement` → `in-development`; `after_converge` → stays `in-development` (converge
  just appends unbuilt work as tasks, it does not certify the feature); `/speckit-engine-verify` (on
  pass) → `in-review`; `/speckit-engine-close` (on sign-off) → `done`. Several commands may map to the
  same state; the card advances when a command crosses into a new one. Every command produces a
  sync (content and/or status); a command that changes nothing is still a no-op sync, not a
  skipped one.
- **FR-013a**: The card MUST be created in `open` at the earliest point a feature exists (at
  provision, before `/speckit-specify`), so the `open → in-design` transition at specify is itself
  visible as "design work started." (This moves card creation earlier than 001, which created it at
  first content sync.)
- **FR-013b**: The engine MUST be wired into a sync hook on **every** lifecycle command, which
  requires **new hooks beyond the three 001 uses** (`after_plan`/`after_tasks`/`after_implement`):
  at minimum `after_specify`, `after_analyze`, and `after_converge`, plus the two new commands
  `/speckit-engine-verify` (US8) and `/speckit-engine-close` (US2). A command with no dedicated sync hook
  available MUST still not leave the card stale — the next command that does fire reconciles it.
  Adding these hooks and commands is in scope for this feature.
- **FR-014**: Unchanged content MUST make zero writes; a status-only change writes only the status
  (constitution III). Idempotent, per 001.
- **FR-015**: The six logical states MUST be **mapped to a list's actual status names in config**
  (names differ per list). Where a list lacks six distinct statuses, the mapping falls back to
  three (not-started / in-progress / done), mapping each logical state to the nearest configured
  one — the sync degrades rather than failing.
- **FR-016**: The command→state mapping and the config'd logical→actual name mapping MUST be
  defined per FR-013/FR-015. The full six-state lifecycle applies to the **feature-card**. **User-story
  subtasks are units of work and MUST use only three states** — not-started / in-progress / done —
  derived from that story's own task completion; a subtask never carries the design/ready/review
  states (those are feature-level concepts). `in-review` at the card level means "all the units of
  work are done; we are now reviewing the feature as a whole."

**Human-review handoff (US4)**

- **FR-017**: The engine (the AI) MUST be the sole writer of the card in the normal flow — every
  status and content write originates from a Spec Kit command or close-out that the AI runs. A
  human is NEVER required to touch the tracker to advance a feature; human decisions are given to
  the flow (in the terminal, at close-out) and the AI reflects them onto the card. The tracker is a
  read-only mirror for humans.
- **FR-017a**: The engine MUST reach `in-review` (state 5) only when `/speckit-engine-verify` passes (US8)
  — never on converge alone — and then **rest there**: the card holds `in-review` with no human
  tracker action, and no further engine write occurs until the human returns and runs close-out.
  "Waiting on a human" is simply the card resting in `in-review` between commands.
- **FR-018**: The engine owns and re-derives all six logical states on every command (one-way, per
  constitution I). The normal flow never requires a human to edit the tracker, so there is no
  human-owned status subset to protect.
- **FR-020**: Human sign-off (via the close-out ceremony, US2) MUST be the path to the terminal
  `done` state: the engine MUST NOT advance a card to `done` on its own while unchecked manual
  tasks remain; close-out's sign-off — given to the AI in the flow — is what checks them and
  triggers the AI's final `done` write. The card rests in `in-review` until then.

**Manual / light mode (US5)**

- **FR-021**: The system MUST support a manually-tracked item (an item with no backing `tasks.md`):
  the engine never derives, reads, or overwrites its status or content — whatever a human set on it
  simply stands, because the engine never touches it (per FR-022).
- **FR-022**: The sync MUST distinguish manual items from spec-driven feature-cards by **ownership
  via manifest presence** (reusing the 001 mechanism): it only ever touches cards recorded in a
  feature's `.clickup-sync.json` manifest and never re-scans the list. A manual item — like any
  unrelated card — is simply never recorded in a manifest, so it is never derived, overwritten, or
  counted. No tag, custom field, or separate registry is required to mark an item as manual.

**Commit/PR provenance (US6)**

- **FR-023**: The system MUST attach the feature's commit provenance to the card via MCP, staying
  one-way (repo → ClickUp), and MUST NOT duplicate links on re-run.
- **FR-024**: Provenance MUST ship as Option A — the extension reads the feature's git log and
  attaches it to the card via MCP (comment / body section / task links), self-contained, needing
  no GitHub remote or commit-message convention. Option B (ClickUp's native GitHub integration via
  `CU-<taskid>` in commit/branch/PR messages) MUST be offered as a documented opt-in for teams
  that connect GitHub — it is not required and not a dependency of the baseline provenance.
- **FR-024a**: Options A and B MUST be mutually exclusive per project. When B (native GitHub
  integration) is opted in, A MUST NOT also push provenance — the extension defers to ClickUp's
  first-party links so the card never shows the same commits/PRs twice. Exactly one provenance
  source is active at a time.

**Agent-designed rules (US7)**

- **FR-025**: The system MUST let an agent inspect the real workspace (space/list/statuses/custom
  fields) and propose a project-specific ruleset for explicit human approval — never silently
  applying board-reshaping changes.
- **FR-026**: An approved ruleset MUST be recorded as config the sync honors; with no ruleset the
  baked-in 001 defaults MUST be used unchanged (opt-in enrichment, defaults always present).
- **FR-027**: A proposed ruleset that would violate a constitution principle (e.g. require two-way
  sync) MUST be rejected, not honored.

**Verify command (US8)**

- **FR-033**: The engine MUST provide a `/speckit-engine-verify` command, run after implementation (and
  after the `after_implement`→converge chain), that in order: (a) recursively reviews the
  implemented code + tests via the consolidated review module (FR-036); (b) runs the full unit
  check gate, which MUST pass; (c) runs every automatable E2E as far as the tooling allows (the US1
  gate, FR-001/002); (d) on success, advances the card to `in-review`.
- **FR-034**: `/speckit-engine-verify` MUST NOT advance the card to `in-review` if the review surfaces an
  unresolved issue, the unit gate is red, or a required verification step fails — it stops, reports,
  and leaves the card at `in-development`. `in-review` is reachable ONLY through a passing verify.
- **FR-035**: `converge` MUST NOT by itself advance the card past `in-development`; it appends
  unbuilt work as tasks. Any converge-added work is therefore still subject to `/speckit-engine-verify`
  before review — the feature cannot reach `in-review` with unbuilt converge work outstanding.

**Consolidate snackbyte lifecycle extensions (US9)**

- **FR-036**: The engine MUST consolidate the five snackbyte-authored lifecycle extensions
  (`git-specify-branch`, `specify-review-loop`, `analyze-autofix`, `git-commit`, `clickup-sync`)
  as command-modules of the one engine extension, each preserving its prior behavior. The engine
  exposes all lifecycle commands plus the tracker-plug interface from a single installed package.
- **FR-037**: The recursive-review module MUST be a single implementation that reviews either the
  **spec** (after specify) or the **code + tests** (inside `/speckit-engine-verify`, FR-033) depending on
  the target it is pointed at — one pattern, two invocation points; the review logic is not
  duplicated.
- **FR-038**: The upstream `agent-context` extension (authored by `spec-kit-core`) MUST NOT be
  absorbed, modified, or broken by the engine — it remains a separate community extension the
  engine coexists with. Only snackbyte-authored extensions are consolidated.
- **FR-039**: Migrating other repos off their scattered copies of these extensions onto the engine
  is OUT OF SCOPE for this feature — the engine is built and proven here first; downstream adoption
  is follow-on work.

**Cross-cutting invariants (engine + plug / constitution)**

- **FR-028**: The engine core MUST NOT talk to any tracker directly; all tracker I/O MUST go
  through a plug that owns its own transport and auth, shipping no API client and no credentials in
  the repo or config (constitution II). For the ClickUp plug, that transport is the ClickUp MCP
  server; another plug would use its own.
- **FR-029**: The sync MUST remain one-way (constitution I): repo → tracker, always. The engine
  never writes back into the repo.
- **FR-030**: All new deterministic logic (status derivation, item classification, provenance
  formatting, ruleset resolution) MUST live in `scripts/bash/` with `*.test.sh` coverage
  (constitution V); each plug's tracker orchestration stays in its command prompts, validated via
  quickstart.
- **FR-031**: The engine and every plug MUST remain scaffolding-only (constitution IV) — no plug
  may put a reference to its tracker into shipped app source/docs/CI of an adopting repo.
- **FR-032**: The engine MUST function with zero external plugs (recording lifecycle state via a
  built-in local plug), one plug, or many at once; plugs MUST be independent and purely additive —
  attaching or removing a plug MUST NOT change engine behavior, and an uninstalled plug is a no-op,
  not an error (constitution VI). Every ClickUp-specific requirement above is satisfied by the
  ClickUp plug; the engine itself requires only "a plug" (the local plug suffices).

### Key Entities *(include if feature involves data)*

- **Status set / lifecycle mapping**: the ordered set of at most six logical states (`open` →
  `in-design` → `ready` → `in-development` → `in-review` → `done`) and their mapping onto a target
  list's real status names, held in config and resolved into the manifest's `statusMapping`. The
  engine owns and writes all of these; the mapping degrades to as few as three (FR-015). Extends
  001's fixed 3-state mapping to six.
- **Handoff report**: the end-of-feature summary the AI produces (in the flow) of what was verified
  automatically vs. what remains manual and why. How/whether it is persisted is an implementation
  detail, not fixed here.
- **Manual item**: a card with no backing `tasks.md` and human-set status/content. Distinguished
  from spec-driven feature-cards purely by **absence from any feature manifest** (FR-022) — not by
  any marker on the card itself.
- **Commit provenance**: the feature's commits/PRs as attached to the card (mechanism per FR-024).
- **Designed ruleset**: agent-proposed, human-approved per-project config that the sync honors,
  layered over the baked-in defaults.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A feature cannot reach a "verified" handoff while its check gate is red — 100% of
  red-gate runs are stopped before handoff.
- **SC-002**: The handoff report, for every feature it is run on, lists at least: feature summary
  + location, automatically-verified items with evidence, and the remaining manual steps — with
  no "verified" claim unbacked by evidence.
- **SC-003**: Close-out never auto-checks a manual task — 100% of manual tasks are checked only
  after explicit human sign-off.
- **SC-004**: After close-out, the tracker card reads done and the close-out edits are committed in
  a distinct commit; the sync step made zero commits.
- **SC-005**: Across a full run of the Spec Kit commands, the card's status advances at each stage
  rather than only at tasks/implement — an observer sees at least one status change per lifecycle
  command that maps to a new state.
- **SC-006**: A status-only change makes zero content writes (a no-op content re-sync stays a
  no-op) — idempotence is preserved under per-command syncing.
- **SC-007**: A feature can be driven from `open` to `in-review` and then to `done` (via close-out
  sign-off) with **zero** human tracker edits — the AI writes every status.
- **SC-008**: A manually-tracked item is never overwritten by the sync — 0% clobber rate on manual
  items — while spec-driven cards in the same list are still reconciled.
- **SC-009**: Commit provenance appears on the card and re-running the sync adds no duplicate
  links.
- **SC-010**: With no designed ruleset present, behavior is byte-for-byte the 001 defaults; a
  designed ruleset is applied only after explicit approval, and one that would break a constitution
  principle is rejected.
- **SC-011**: A target list with fewer statuses than the lifecycle degrades gracefully (nearest
  status, reported) with no failed sync.
- **SC-012**: Close-out re-runs the check gate first and, when the gate is red, refuses to close —
  0% of close-outs proceed (sign-off / final sync / commit) over a red gate.
- **SC-013**: The engine produces a correct lifecycle with zero external plugs (local plug only),
  one plug, and many plugs; adding or removing a plug changes only how many trackers are mirrored,
  never the derived lifecycle — an uninstalled plug causes no error.
- **SC-014**: A card reaches `in-review` only after `/speckit-engine-verify` passes (code review + green
  unit gate + automatable E2E) — 0% of features reach `in-review` with a red gate or unresolved
  review findings; `converge` alone never advances past `in-development`.
- **SC-015**: The engine exposes the five consolidated snackbyte lifecycle modules (branch-setup,
  recursive review, analyze-autofix, commit checkpoint, ClickUp plug) from one installed package,
  each matching its former standalone behavior; the recursive-review logic exists once and serves
  both spec and code targets; the upstream `agent-context` extension is neither absorbed nor broken.

## Assumptions

- **Independent, prioritized slices**: the user stories are specified together but remain
  independently deliverable; §0 (US1–US2) and the verify command (US8) are pure engine and can ship
  with no external tracker plug at all, each ClickUp-facing track (US3–US7) builds on the shipped
  ClickUp plug without revisiting its core mapping, and consolidation (US9) is the engine's
  structural foundation.
- **The ClickUp plug is the proven base**: `001-clickup-sync` (the ClickUp plug) is shipped and
  validated (one-way, MCP-only, idempotent, scaffolding-only); this feature generalizes its model
  into the engine and extends it — it does not re-implement the plug.
- **Constitution governs**: all six engine principles hold. The AI is the sole tracker writer in
  the normal flow (US4); human decisions are inputs to the flow that the AI reflects onto the card,
  so there is no competing human write-path to reconcile — principle I (one-way) holds cleanly, and
  the tracker is a read-only mirror for humans.
- **E2E is best-effort**: the verify phase drives whatever end-to-end testing the AI can automate
  for the feature at hand and reports the rest as manual — it does not assume a fixed E2E harness.
- **Handoff report** is produced by the AI in the flow; where (if anywhere) it is persisted is left
  to implementation, not pinned in this spec.
- **Non-goals** (from the backlog): no two-way sync of task content back into `tasks.md`; no change
  to 001's core mapping (feature = card, line = checklist item); no app-specific E2E logic baked
  into the template (only the generic hook + per-app extension point).
- **Split-vs-combined**: the original backlog recommended splitting these tracks into separate
  feature dirs; per explicit direction this spec intentionally carries them all as one engine
  feature, using prioritized user stories to keep them independently deliverable.
- **Six-state card, three-state subtasks**: the feature-card advances through six logical states
  (`open` → `in-design` → `ready` → `in-development` → `in-review` → `done`), one per meaningful
  lifecycle transition, mapped to each project's real status names in config and degradable to a
  three-state floor. User-story subtasks are units of work and use only not-started / in-progress /
  done. Chosen so the card's artifact phase is visible as work (design counts) while subtasks stay
  simple, and so the mapping survives lists with as few as three statuses (FR-012/015/016).
- **Sign-off and "done" (FR-020 default)**: human sign-off is not a separate gate bolted onto the
  status machine — it is the close-out ceremony (US2), which is the path to "done" for any feature
  with manual tasks. The sync never advances a card to "done" while unchecked manual tasks remain.
- **Resolved design forks**: the genuine forks (close-out trigger, red-gate failure contract,
  provenance mechanism, manual-item discriminator, the six-state lifecycle, the `/speckit-engine-verify`
  handoff, and extension consolidation) were decided across the design sessions — see the
  `## Clarifications` section. No open clarification markers remain.
- **Carried-over validation from 001 (SC-007 negative path)**: 001's live validation (T030,
  2026-07-11) exercised every positive scenario plus one-way/idempotence against a real workspace
  but did NOT trigger the provision fail-loud path where a target list cannot represent the logical
  states as distinct statuses — every list in the workspace ships the full 9-status set, so it
  needs a purpose-built degenerate list. The fail-loud logic exists in the 001 provision contract;
  only the live trigger is unverified. Because this feature's provisioning/lifecycle work
  (US3/US7) touches status resolution, that negative path MUST be exercised as part of this
  feature's validation (build a degenerate list; confirm provision stops, names the gap, and
  leaves the manifest untouched).
