<!--
SYNC IMPACT REPORT
Version change: 2.0.0 → 2.1.0
Bump rationale: MINOR — one new principle added (VII. Earned Handoff); no existing principle
  removed or redefined. VII codifies the doctrine already implied across the command bodies:
  every altitude of work reaches the human only through AI self-review, maximal automatable
  self-testing, and a handoff that states verified-vs-remaining. It also names the review
  module (targets: spec | analysis | code) as the doctrine's review stage — the basis for
  merging the former analyze-autofix extension into review-loop (2026-07-26).
Modified principles: none.
Added principle:
  VII. Earned Handoff — work → self-review → self-test → handoff, at every altitude;
     state shims (git, tracker) record transitions at handoff boundaries.
Added sections: none beyond the new principle.
Removed sections: none.
Templates requiring updates:
  ✅ .specify/templates/plan-template.md — Constitution Check gate is generic; still aligns.
  ✅ .specify/templates/spec-template.md — no mandatory-section conflict.
  ✅ .specify/templates/tasks-template.md — test-first categorization consistent with V + VII.
Deferred TODOs: none.
Previous report (1.0.0 → 2.0.0, subject change to "engine + plugs"): see git history.
-->
# snackbyte-speckit-engine Constitution

A Spec Kit lifecycle engine that mirrors each feature's lifecycle out to swappable tracker
**plugs** (ClickUp is the first plug). This constitution captures the guarantees the engine makes
to any repo that adopts it, and the contract every plug must honor. The principles are
non-negotiable invariants, not aspirations: a change that violates one is a defect, not a
trade-off.

## Core Principles

### I. One-Way, Repo Is Source of Truth
The lifecycle flows in exactly one direction: repo → plug(s). The engine and its plugs MUST
overwrite each tracker toward the repo and MUST NOT write back to `tasks.md`, `spec.md`, or any
other repo artifact. A hand-edit made in a tracker is transient and MUST be reverted on the next
sync (except a plug's explicitly-bounded human-owned states, which the plug declines to write —
still never a write-back into the repo). There is no bidirectional mode and no "merge" — the repo
wins, always.
Rationale: bidirectional sync creates ambiguous conflict resolution and lets a PM tool mutate
source. One direction keeps the repo authoritative and the reasoning trivial across any number of
plugs.

### II. Plugs Own All Tracker I/O
The engine core MUST NOT talk to any external tracker directly. Every tracker operation MUST go
through a plug, and each plug owns its own transport and authentication — the engine ships no API
client, no auth flow, and no credentials for any tracker. No plug may commit credentials to the
repo; config names only WHERE (e.g. a space/list), never secrets. (The ClickUp plug's instance of
this: all ClickUp I/O goes through the connected ClickUp MCP server, which owns auth.)
Rationale: the engine stays tracker-agnostic and credential-free; each integration's transport is
isolated behind the plug boundary, so adding a tracker never touches the core.

### III. Idempotent
Running the sync when nothing changed MUST make zero tracker writes, per plug. Create/update/skip
decisions are driven by the committed per-feature manifest (e.g. `specs/<feature>/.clickup-sync.json`
for the ClickUp plug) via content hashes and recorded target IDs. Re-running is always safe and
never duplicates items, subtasks, or checklist lines in any plug.
Rationale: idempotence makes the lifecycle safe to wire into hooks that fire repeatedly, and makes
a no-op observable (zero writes) rather than merely harmless.

### IV. Scaffolding-Only
The engine and its plugs MUST live entirely under `.specify/`, `.claude/`, and per-feature
manifests. No plug MUST introduce a reference to its tracker into shipped application source,
product docs, or CI of the repo that adopts it. Runtime tracker IDs are confined to the per-feature
manifest — the only place they are committed.
Rationale: an adopting repo's product and pipeline stay clean and tracker-agnostic; the engine and
any plug are fully removable by deleting scaffolding.

### V. Deterministic Logic Is Tested (NON-NEGOTIABLE)
All deterministic logic — `tasks.md` parsing, status derivation, manifest I/O, hashing, plug item
classification — MUST live in `scripts/bash/` and MUST carry `*.test.sh` unit coverage that passes
before any change is committed. The non-deterministic tracker orchestration lives in the command
prompts and is validated manually against a real tracker via the feature's `quickstart.md`; it
MUST NOT embed deterministic logic that belongs in a tested script.
Rationale: the parts that can be tested cheaply must be; the boundary between tested bash and
manually-validated tracker orchestration is deliberate and must not blur.

### VI. Plugs Are Additive (Zero / One / Many)
The engine MUST run with zero external plugs (recording lifecycle state via a built-in local
plug), one plug, or many plugs at once. Plugs are independent — they do not know about each other —
and MUST be purely additive: attaching or removing a plug MUST NOT change what the engine does, only
how many trackers the lifecycle is mirrored to. A plug that is not installed is a no-op, never an
error.
Rationale: this is the whole point of the engine — the lifecycle is the product; trackers are
interchangeable mirrors. Additivity keeps the engine correct regardless of which plugs are present.

### VII. Earned Handoff: Work → Self-Review → Self-Test → Hand Off (NON-NEGOTIABLE)
Every altitude of work — spec, design artifacts, code — MUST reach the human only through the
same sequence: the AI does the work; the AI reviews its own output with the review module
(targets: `spec` | `analysis` | `code`), fixing every issue that has a single obvious correct
resolution and never deciding product questions; the AI then tests everything automatable at
that altitude (cross-artifact analysis for design; the unit gate plus all automatable E2E for
code); and the handoff states what was done, what was fixed, what was verified automatically
(with evidence), and what remains for human judgment. Lifecycle state (git checkpoints, tracker
status) MUST be recorded at handoff boundaries, so the next unit of work initiates from
recorded state rather than memory.
Rationale: agent capacity is spent on verification so human attention is spent on judgment. A
handoff that arrives unreviewed, untested, or unlabeled externalizes the AI's work onto the
human; an unrecorded transition makes the next step start from guesswork. This principle is the
engine-level form of the maintainer's testing discipline and governs every command and plug.

## Additional Constraints

- **Config-only retargeting**: pointing a plug at a different tracker target MUST require editing
  only that plug's config — never a code change. A plug MUST refuse to run while its config still
  holds `<...>` placeholders (or ask once and remember a decline, never re-prompting).
- **No node package**: the engine and its plugs are `extension.yml` + config + markdown command
  prompts + bash. They MUST NOT acquire a `package.json` publish contract or importable JS; they
  are distributed as Spec Kit presets/extensions. (A root `package.json` used solely to run the
  local check gate is permitted; it is not a publish contract.)

## Development Workflow

- **Test gate**: the full `scripts/bash/*.test.sh` suite MUST pass locally before a commit that
  touches deterministic logic. New deterministic behavior lands with its test in the same change
  (test-first where it fits).
- **Manual tracker validation**: changes to a plug's command-prompt orchestration are validated by
  running the feature `quickstart.md` against a real tracker (e.g. a real ClickUp workspace for the
  ClickUp plug), since tracker side effects cannot be unit-tested here.
- **Amendments**: changes to this constitution follow the Governance rules below.

## Governance

This constitution supersedes ad-hoc practice for this repo. Amendments MUST be made by editing this
file, with the version bumped per the policy below and the change recorded in the Sync Impact
Report at the top.

Versioning policy (semantic):
- **MAJOR**: a principle is removed or redefined in a backward-incompatible way, or the governed
  unit changes.
- **MINOR**: a new principle or section is added, or guidance is materially expanded.
- **PATCH**: clarifications, wording, or non-semantic refinements.

Compliance: any change to the engine or a plug MUST be checked against these principles before it
is committed; a change that breaks an invariant is a defect. Complexity that appears to require
violating a principle MUST instead be justified and, if genuinely warranted, ratified as an
explicit amendment first.

**Version**: 2.1.0 | **Ratified**: 2026-07-07 | **Last Amended**: 2026-07-26
