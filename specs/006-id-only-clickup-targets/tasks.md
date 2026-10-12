# Tasks: ID-only ClickUp targets

**Input**: Design documents from `specs/006-id-only-clickup-targets/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required. Constitution V makes deterministic logic test-first. Every script change lands
with its `*.test.sh` in the same change.

## Format: `[ID] [P?] [Story] Description`

## Phase 1: Setup

- [x] T001 Create `.specify/extensions/clickup/scripts/bash/targets.sh`: shebang, `set -euo pipefail`, usage, subcommand + `--config-dir` parsing, exit 2 on usage errors. Create the `targets.test.sh` harness in the engine test style (ok/bad/FAIL_F, temp dirs, trap cleanup).

## Phase 2: Foundational (blocks all stories)

- [x] T002 Tests in `.specify/extensions/clickup/scripts/bash/targets.test.sh` for the layered flat reader:
  - precedence: env > `local-config.yml` > `clickup-config.yml` > `extension.yml` defaults
  - legacy grace: `config.local.yml`/`config.yml` are read only when neither new file exists
  - `<...>` placeholders count as absent
  - quotes are stripped; a trailing unquoted `# comment` is stripped; indented lines are ignored
- [x] T003 Implement the layered flat reader in `.specify/extensions/clickup/scripts/bash/targets.sh` (research R9) until T002 passes
- [x] T004 Amend Constitution Principles II and IV in `.specify/memory/constitution.md` (FR-017): config identifies WHERE by ID; IDs are committed only in plug config (containers) and the feature manifest (items); a name never locates a container. Bump to 3.0.0 with a Sync Impact Report.

## Phase 3: User Story 1 - A repo provisions into exactly the list it pins (Priority: P1) 🎯 MVP

**Goal**: A pinned `list-id` is used as-is, verified live by ID, and never looked up.

**Independent Test**: quickstart Scenario 1 (karaoke → 901421288946).

- [x] T005 [US1] Tests in `.specify/extensions/clickup/scripts/bash/targets.test.sh`:
  - `resolve` → `ready/existing` JSON with workspace, space and list IDs
  - a name key with its ID present is inert
  - `folder-id` is ignored when `list-id` is set
  - `enabled: false` → `disabled`
  - nothing set → `unconfigured`
- [x] T006 [US1] Implement `resolve` (existing path, `disabled`, `unconfigured`) in `.specify/extensions/clickup/scripts/bash/targets.sh`
- [x] T007 [US1] Rewrite `.specify/extensions/clickup/commands/speckit.clickup.provision.md`:
  - resolve the target via `targets.sh resolve`
  - existing path: `clickup_get_list(list_id, workspace_id)`; not-found stops naming `list-id` and the ID (no cross-checks)
  - status mapping by name, as the stated exception
  - `set-targets` from the resolved target; card created with `workspace_id`
  - no hierarchy browse, no `*_name` parameters
- [x] T008 [P] [US1] Update `.specify/extensions/clickup/commands/speckit.clickup.sync.md`: pass `workspace_id` (the manifest's `workspaceId`) on every ClickUp call; the precondition requires `workspaceId`; state the status-by-name exception
- [x] T009 [P] [US1] Update `.specify/extensions/clickup/commands/speckit.clickup.design-rules.md`: inspect the pinned list by ID (`clickup_get_list`, `clickup_get_custom_fields`) with `workspace_id`; no hierarchy browse
- [x] T010 [US1] Pin this repo's target by ID in `.specify/extensions/clickup/clickup-config.yml` (platforms / speckit-engine / Roadmap, FR-020)
- [x] T011 [US1] Bring the skill mirrors in line with their commands: `.claude/skills/speckit-clickup-provision/SKILL.md`, `.claude/skills/speckit-clickup-sync/SKILL.md`, `.claude/skills/speckit-clickup-design-rules/SKILL.md`

## Phase 4: User Story 2 - A config without IDs fails loudly, naming the key (Priority: P1)

**Goal**: Any incomplete or name-based config stops provision before a ClickUp call, listing every offending key.

**Independent Test**: quickstart Scenario 2 (karaoke's current config) and Scenario 3.

- [x] T012 [US2] Tests in `.specify/extensions/clickup/scripts/bash/targets.test.sh`. Each case → exit 1 + `invalid` JSON with key-first messages, and all errors are listed in one run:
  - a name key without its ID
  - `workspace-id` / `space-id` missing
  - no `list-id` and no `folder-id`
  - `folder-id` without `new-list-name`
  - a non-numeric `*-id`
- [x] T013 [US2] Implement the validations in `.specify/extensions/clickup/scripts/bash/targets.sh` until T012 passes
- [x] T014 [US2] In `.specify/extensions/clickup/commands/speckit.clickup.provision.md`:
  - `invalid` → print the errors and stop with zero ClickUp calls
  - ask-once runs only on `unconfigured`, and asks for IDs and where to find them (FR-014)
- [x] T015 [P] [US2] Document the ID contract and the migration from name-based config:
  - `.specify/extensions/clickup/README.md` (Configure, State)
  - `docs/CONSUMING.md` (Configure)
  - `docs/MIGRATION.md` (new section)
  - `README.md` (config snippet)

## Phase 5: User Story 3 - A new product's first feature creates its list and pins it (Priority: P2)

**Goal**: `folder-id` + `new-list-name` creates one list in the folder, pins its ID, and the pin is committed with the spec.

**Independent Test**: quickstart Scenario 4, plus `commit-spec-artifacts.test.sh`.

- [x] T016 [US3] Tests in `.specify/extensions/clickup/scripts/bash/targets.test.sh`:
  - `resolve` → `ready/create`
  - `pin-list` rewrites the `new-list-name` line, or appends when the name came from an override layer; every other byte is unchanged
  - `pin-list` refuses: a non-numeric ID, an already-pinned `list-id`, a missing file
- [x] T017 [US3] Implement the create path in `resolve` and the `pin-list` subcommand in `.specify/extensions/clickup/scripts/bash/targets.sh`
- [x] T018 [US3] Add the create path to `.specify/extensions/clickup/commands/speckit.clickup.provision.md`:
  - `clickup_get_folder(folder_id, workspace_id)`; not-found stops naming `folder-id`
  - `clickup_create_list_in_folder`
  - `targets.sh pin-list` immediately after creating
  - a pin failure stops, printing the ID and the line to add
- [x] T019 [US3] Create `.specify/extensions/git-lifecycle/scripts/bash/commit-spec-artifacts.test.sh` (throwaway git repo). The checkpoint commit:
  - includes the feature's spec dir and a modified or untracked `.specify/extensions/*/*-config.yml`
  - excludes `local-config.yml`, gitignored files and unrelated changes
- [x] T020 [US3] Widen `.specify/extensions/git-lifecycle/scripts/bash/commit-spec-artifacts.sh` until T019 passes. Update the matching wording in `.specify/extensions/git-lifecycle/commands/speckit.git-lifecycle.commit.md`.

## Phase 6: User Story 4 - The check gate stops name resolution from coming back (Priority: P2)

**Goal**: Reintroducing name-based resolution fails `npm run check:all`, naming file and line.

**Independent Test**: quickstart Scenario 0.

- [x] T021 [US4] Create `.specify/scripts/bash/id-only-guard.test.sh`:
  - fixtures that each violate G1, G2, G3 and G4 → the guard exits 1 naming file:line and rule
  - a clean fixture → exit 0
  - the real repo → exit 0
- [x] T022 [US4] Implement `.specify/scripts/bash/id-only-guard.sh` per contracts/id-only-guard.md until T021 passes

## Phase 7: Polish & Cross-Cutting

- [x] T023 [P] Add this repo's current real IDs (90146747064, 901411097129, 901418532190) to `FORBIDDEN_CONTENT` in `.specify/scripts/bash/release.sh`. Keep the old ones. `release.test.sh` stays green.
- [x] T024 [P] Update the provision command description in `.specify/extensions/clickup/extension.yml` (hooks unchanged, so wiring fidelity holds)
- [x] T025 Run `npm run check:all`, then quickstart Scenarios 0–7 live. Record the evidence (IDs, read-backs, the status-by-ID result) in `specs/006-id-only-clickup-targets/VALIDATION.md`.

- [x] T026 [manual] Jeff confirms deletion of the E2E list `901422173368` (`speckit-engine-e2e-delete-me`, platforms / speckit-engine). Then delete it through the self-hosted ClickUp MCP (`clickup_delete_list`) and read it back as not found (quickstart Scenario 6, SC-005).

## Dependencies & Execution Order

- Phase 2 (T002–T003) blocks every story. T004 is independent.
- US1 (T005–T011) → US2 (T012–T015) build on the same script and provision body, in order.
- US3 (T016–T020) needs US1's provision structure. T019–T020 are independent of the plug files.
- US4 (T021–T022) runs last so the guard checks the final command bodies.
- T008, T009, T015, T023 and T024 touch disjoint files ([P]).
