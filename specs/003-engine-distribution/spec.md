# Feature Specification: Engine Distribution — versioned, catalog-installable releases

**Feature Branch**: `003-engine-distribution`

**Created**: 2026-07-24

**Status**: Draft

**Input**: User description: "Package the engine and its plugs as versioned, catalog-installable
Spec Kit extensions so other repos (Claude Code and GitHub Copilot) can install and update them by
name — no hand-migration. First official release: every component ships at 1.0.0 and all
components share one release version from here on (lockstep)."

## Clarifications

### Session 2026-07-24

- Q: Where does the release step run? → A: Local script — maintainer runs one command locally;
  it gates on the check gate, builds archives, and publishes the release + catalog via the
  GitHub CLI. (CI-driven publishing deliberately out of scope; the same script may graduate to
  CI in a later feature.)
- Resolved by inspection (no question spent): the repo is public, so catalog/archive downloads
  need no consumer authentication; the CLI is upstream `github/spec-kit` with extension support
  in tagged releases from v0.13.0 — consumers install a normal released CLI.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Maintainer publishes a versioned release (Priority: P1)

The maintainer finishes a change to the engine or a plug, bumps the release version once, and runs
one release step. Out come installable archives for all four extensions plus an up-to-date catalog
that names each extension at the new version and where to download it. Nothing maintainer-local
(private config values, caches, scratch files) leaks into any archive.

**Why this priority**: every other story consumes what this one produces. Without a published,
versioned artifact there is nothing to install or update — this is the release train's engine.

**Independent Test**: run the release step on this repo, inspect the produced archives and catalog:
four archives exist, each carries the shared release version, the catalog references exactly those
archives, and a scan of archive contents finds zero maintainer-local values.

**Acceptance Scenarios**:

1. **Given** the repo at a tagged release version, **When** the maintainer runs the release step,
   **Then** one installable archive per extension (engine, clickup, git-lifecycle, review-loop) is produced and attached to a published release, and the catalog lists all
   four at that version with working download locations.
2. **Given** a maintainer working copy containing local-only config (e.g. the ClickUp plug's
   `config.local.yml` with real space/list names), **When** archives are built, **Then** no archive
   contains any local-only file, and the shipped plug config holds only the `<...>` placeholders.
3. **Given** an extension whose declared version does not match the release version, **When** the
   release step runs, **Then** it fails loudly, naming the mismatched extension, and publishes
   nothing.
4. **Given** no changes since the last release, **When** the release step is re-run for the same
   version, **Then** the result is byte-identical archives (repeatable builds) or an explicit
   refusal to republish an existing version — never a silently different artifact under the same
   version.

---

### User Story 2 - Consumer installs the whole engine by name (Priority: P1)

A user with a fresh Spec Kit repo (Claude Code integration) registers the engine's catalog once,
then installs the engine by name. All four extensions arrive as one coherent set: every command is
available to the agent, lifecycle hooks are wired, and the plug refuses to sync until its config
is filled in — exactly as designed.

**Why this priority**: this is the feature's reason to exist — the engine becomes usable in another
repo without cloning this one or hand-copying files. Together with Story 1 it is the MVP.

**Independent Test**: in a throwaway Spec Kit repo, register the catalog and install by name; count
the rendered agent commands, diff the wired hooks against the engine's canonical wiring, and run a
lifecycle command to see the placeholder guard hold.

**Acceptance Scenarios**:

1. **Given** a fresh Spec Kit repo that has never seen the engine, **When** the user registers the
   catalog and requests the engine, **Then** all four extensions install at the same release
   version and every engine and plug command is invocable from the agent.
2. **Given** the ClickUp plug depends on the engine extension, **When** a user requests only the
   ClickUp plug, **Then** the outcome is never a broken half-install: the dependency is satisfied
   automatically or the install refuses with a message naming the missing engine extension.
3. **Given** a completed install, **When** the user compares the repo's hook wiring with the
   engine's canonical wiring, **Then** the hook set, execution order, enablement, and user-facing
   prompt texts match it (Story 5 defines the fidelity details).
4. **Given** a freshly installed plug whose config still holds placeholders, **When** a lifecycle
   command triggers the plug, **Then** the plug asks or declines per its config contract — it never
   syncs to a wrong target.

---

### User Story 3 - Consumer updates without hand-migration (Priority: P2)

A repo that installed release N learns that release N+1 exists, runs one update action, and is
current: replaced engine files, preserved local configuration (filled-in plug config, hook
enable/disable choices), untouched per-feature manifests, and no manual file surgery.

**Why this priority**: "increments with versions so we don't hand-migrate" is the original ask.
It ranks below install only because update is meaningless until install exists.

**Independent Test**: install release N in a scratch repo, customize its config, publish an N+1,
update, then verify version, preserved customizations, and a still-working lifecycle.

**Acceptance Scenarios**:

1. **Given** a repo on release N with a filled-in plug config and one hook deliberately disabled,
   **When** the user updates to N+1, **Then** all four extensions report N+1, the plug config
   values and the disabled hook survive, and per-feature manifests are untouched.
2. **Given** an update is available, **When** the user asks what is installed, **Then** installed
   version and latest available version are both visible before anything changes.
3. **Given** a repo where someone hand-edited a shipped engine file, **When** an update runs,
   **Then** the edit is not silently destroyed: the update surfaces the conflict (or preserves the
   edit) rather than overwriting without notice.
4. **Given** a repo carrying a pre-release hand-copied plug (the old `clickup-sync` id at its old
   version, as deployed in bed-generators, snackbyte-discord, snackbyte-links), **When** its owner
   follows the documented migration path to the catalog-managed install, **Then** existing
   per-feature manifests keep working (no re-provisioning, no duplicate cards) and the old copy is
   fully superseded.

---

### User Story 4 - A friend on GitHub Copilot adopts the engine (Priority: P2)

A friend whose repo uses the GitHub Copilot integration follows the same catalog registration and
install-by-name flow. The engine's commands appear in Copilot's native command form, and a
documented setup path gets the ClickUp plug talking to their own ClickUp workspace.

**Why this priority**: the second supported agent proves the engine is not Claude-only and is the
stated audience ("me and maybe my friends who use GitHub Copilot"). It depends on Stories 1–2.

**Independent Test**: in a scratch repo initialized for Copilot, install from the catalog, verify
all engine and plug commands render in Copilot's command form, and follow the written ClickUp
setup doc to a live provision + sync against a test workspace.

**Acceptance Scenarios**:

1. **Given** a fresh Spec Kit repo initialized for the Copilot integration, **When** the engine is
   installed from the catalog, **Then** every engine and plug command is available in Copilot's
   native command form, at parity with the Claude command set.
2. **Given** a Copilot user with no ClickUp connection configured, **When** they follow the
   consumer setup documentation, **Then** they reach a working provision + sync against their own
   ClickUp workspace without reading this repo's source.

---

### User Story 5 - Installed hook wiring matches the curated wiring (Priority: P3)

The engine's own repo carries deliberately tuned lifecycle wiring: per-hook prompts that say what a
sync will do ("Sync this feature's card to ClickUp (→ in-design)?"), priorities that order the
review loop before the tracker sync, and mandatory-vs-optional flags. A fresh install today
regenerates generic wiring ("Execute speckit.clickup.sync?") and loses that ordering intent. After
this feature, what a consumer's repo wires up is equivalent to what the maintainer curated.

**Why this priority**: the engine works without it — but consumers get a degraded, confusing
experience (vague prompts, wrong hook order) that the maintainer already solved once. Fidelity
turns "installed" into "installed as designed".

**Independent Test**: fresh-install into a scratch repo and field-by-field compare the generated
hook wiring against this repo's canonical wiring for the same extension set.

**Acceptance Scenarios**:

1. **Given** the canonical wiring in this repo, **When** the engine set is freshly installed
   elsewhere, **Then** for every hook the prompt text, description, ordering priority, and
   optional/mandatory flag match the canonical values.
2. **Given** two extensions hook the same lifecycle point (e.g. review loop and tracker sync after
   specify), **When** installed fresh, **Then** their relative execution order matches the
   canonical order.

---

### Edge Cases

- Catalog location unreachable (offline, moved, or access denied): install/update must fail with a
  clear message and change nothing — never a partial install.
- A consumer repo whose recorded plug version is *higher* than the catalog's (the pre-release
  clickup at 2.0.0 vs. first official 1.0.0): the flow must not treat "already newer" as success;
  the migration path (Story 3, scenario 4) governs.
- Only a subset of the four extensions installed (e.g. engine + clickup, no git-lifecycle extension): the
  lifecycle must still run; hooks referencing absent extensions must not fire or error.
- Re-running install over an existing same-version install: must be a safe no-op or clean refusal,
  never a duplicate or corrupted state.
- A release is published, then a defect is found: publishing a fixed release under a *new* version
  must be the path; the process must not enable silently replacing an already-published version's
  artifacts.
- Archive downloads require repository access (private hosting): the failure must name the access
  problem, and the consumer documentation must state what access a consumer needs.
- A consumer later switches agent integration (e.g. a repo moves from Copilot to Claude Code):
  re-rendering the engine's commands for the new agent must be possible without losing consumer
  state or reinstalling from scratch; at minimum the documented path covers it.

## Requirements *(mandatory)*

### Functional Requirements

**Release & versioning**

- **FR-001**: A single release version MUST cover all four extensions (lockstep); the first
  official release is 1.0.0 for every component. A release in which any extension declares a
  different version MUST fail to build.
- **FR-002**: The release step MUST produce one installable archive per extension, each
  installable by the Spec Kit extension mechanism on spec-kit ≥ 0.13.
- **FR-003**: Release archives MUST exclude maintainer-local and generated content — at minimum
  local config overrides (`config.local.yml`), caches, and anything gitignored. Shipped plug
  config MUST contain only placeholder targets.
- **FR-004**: A machine-readable catalog MUST be published at a stable HTTPS location, listing
  every extension with its release version and archive download location; registering that one
  catalog MUST be sufficient for install-by-name and update discovery.
- **FR-005**: The deterministic parts of release packaging (file selection, version consistency
  checks, catalog generation) MUST be scripted with unit-test coverage wired into the existing
  check gate, per Constitution Principle V; a release MUST NOT be publishable with the gate red.
  The release step is a single maintainer-run local command (per Clarifications 2026-07-24);
  publishing happens through the repo hosting's CLI, and no CI pipeline is part of this feature.
- **FR-006**: The release process MUST be documented end-to-end (bump → build → publish →
  announce) such that a future release requires no rediscovery.

**Install**

- **FR-007**: A consumer MUST be able to go from "never heard of the engine" to "all four
  extensions installed at the current release" using only the catalog registration and
  install-by-name steps — without cloning this repo.
- **FR-008**: The ClickUp plug's dependency on the engine extension MUST be honored at install
  time: satisfied automatically, or refused with a message naming the missing dependency. A
  silent broken install is a defect.
- **FR-009**: Install MUST work on repos using the Claude Code integration and repos using the
  GitHub Copilot integration, yielding the full command set in each agent's native form. Other
  integrations are out of scope for this release.
- **FR-010**: The engine set MUST be installable as one intent (a documented single flow or
  grouped install), not four undocumented independent installs whose completeness the consumer
  must guess.

**Update & migration**

- **FR-011**: A consumer on release N MUST reach release N+1 via the standard extension update
  flow with zero manual file edits, and MUST be able to see installed vs. available versions
  before updating.
- **FR-012**: Update MUST preserve consumer-owned state: filled-in plug config, local config
  overrides, hook enable/disable choices, and per-feature manifests. Shipped files it replaces;
  consumer state it never clobbers. A hand-edited shipped file MUST NOT be overwritten silently.
- **FR-013**: A documented migration path MUST exist from pre-release hand-copied installs (the
  `clickup-sync`-id copies in existing repos, including their higher pre-release version numbers)
  to catalog-managed 1.0.0 installs, preserving existing per-feature manifests (no duplicate
  tracker items, no forced re-provisioning).

**Wiring fidelity**

- **FR-014**: Extension packaging MUST carry enough hook metadata (prompt text, description,
  ordering priority, optional/mandatory flag) that a fresh install reproduces the canonical
  wiring this repo curates, per User Story 5. Where the extension mechanism cannot express a
  field, the gap MUST be closed in this feature or explicitly documented as a known difference —
  never silently degraded.

**Consumer documentation**

- **FR-015**: Consumer-facing documentation MUST cover: catalog registration, install, update,
  uninstall, per-repo plug configuration, and — for Copilot users — connecting the ClickUp plug's
  tracker access in their environment. It MUST be readable standalone (no source spelunking).

### Key Entities

- **Release**: one shared version stamped across all four extensions; owns a set of archives and
  one catalog state. Immutable once published; defects roll forward to a new version.
- **Extension archive**: the installable form of one extension — its declaration, commands,
  scripts, and placeholder config; explicitly excludes maintainer-local and generated content.
- **Catalog**: the machine-readable index consumers register once; maps extension names to
  versions and archive locations; the single discovery point for install and update.
- **Consumer repo state**: what belongs to the adopting repo, never to a release — filled-in plug
  config and local overrides, hook enablement choices, per-feature manifests, and the repo's
  record of installed extensions/versions.
- **Canonical wiring**: the maintainer-curated lifecycle hook set (order, prompts, flags) that
  installs must reproduce (per FR-014).

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A fresh Spec Kit repo reaches a fully installed engine (all four extensions, full
  command set) in at most 3 consumer-run commands and under 5 minutes, without cloning this repo.
- **SC-002**: Publishing a new release requires exactly one version-bump action (a single command
  or single-file edit, however many files it stamps) plus one release step by the maintainer; the
  check gate blocks any release with inconsistent versions.
- **SC-003**: Updating a consumer repo from release N to N+1 takes one action and zero manual
  file edits, with 100% of consumer-owned state (config values, hook choices, manifests)
  preserved — verified by byte-comparison of the consumer-owned files before and after.
- **SC-004**: 100% of hook wiring fields (prompt, description, priority, optionality, ordering)
  in a fresh install match the canonical wiring, field for field.
- **SC-005**: Zero maintainer-local values are present in any published artifact, verified by an
  automated scan of every archive in the release.
- **SC-006**: Both supported agent integrations complete the full journey — install, configure,
  provision, live tracker sync — in a clean repo each, closing VALIDATION.md's "consolidated
  spine in a clean repo" item and exercising its plug-seam scenario in consumer conditions.
- **SC-007**: At least one repo not owned by the maintainer (a friend's) completes install +
  first sync using only the consumer documentation; every support intervention that proves
  necessary is treated as a documentation defect and results in a documentation fix.

## Assumptions

- The Spec Kit CLI's extension mechanism (upstream `github/spec-kit`, tagged releases from
  v0.13.0; verified against 0.13.5-dev: install-by-name, custom-URL and catalog-based install,
  per-extension registry with versions, update flow, per-integration command rendering for Claude
  Code and Copilot) is the distribution substrate. Consumers install a normal released CLI
  (≥ 0.13; 0.14.x is current at spec time — compatibility across 0.13/0.14 is checked during
  implementation). This feature builds on it rather than inventing a parallel installer —
  consistent with the constitution's "distributed as Spec Kit presets/extensions" constraint.
- Versioning is lockstep by decision (2026-07-24): one release version across all four
  extensions, starting at 1.0.0 as the first official release. The pre-release clickup "2.0.0"
  is superseded by the migration path (FR-013), not by version arithmetic.
- Release archives and the catalog are hosted with this repo's hosting (release assets + a raw
  HTTPS catalog file). The repo is public (verified 2026-07-24), so no consumer authentication is
  required to download the catalog or archives.
- Supported agents for this release are Claude Code and GitHub Copilot only (user decision);
  the extension mechanism's other integrations are untested and out of scope.
- Consumers run installs/updates interactively in their own repos; unattended/CI-driven update
  is out of scope.
- Releases are published from the maintainer's machine by one tested local script (user decision
  2026-07-24); CI-driven publishing is out of scope and, if wanted later, reuses the same script.
- The upstream `agent-context` extension remains a separate community extension (FR-038 of 002):
  it is not packaged, listed, or modified by this feature, and installs alongside without
  conflict.
- Out of scope: new tracker plugs, lifecycle behavior changes, the profiles work parked as
  `specs/backlog/004-lifecycle-profiles`, and contributing the catalog upstream.
