# Tasks: Engine Distribution — versioned, catalog-installable releases

**Input**: Design documents from `/specs/003-engine-distribution/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included where Constitution V demands them (all deterministic release/fidelity logic
is test-first bash); E2E scenarios come from quickstart.md.

**Organization**: Tasks are grouped by user story. Note the suite is **four** extensions
(engine, clickup, git-lifecycle, review-loop) after the 2026-07-26 merge.

**Format**: `[ID] [P?] [Story] Description`

## Phase 1: Setup (shipping hygiene on the existing extensions)

- [X] T001 [P] Add `.extensionignore` to each extension dir — `.specify/extensions/clickup/.extensionignore` (local config names: `config.local.yml`, `local-config.yml`, `clickup-config.yml`; caches/backups/OS junk) plus minimal defensive ones in `engine/`, `git/`, `review-loop/` (caches/backups/junk; the file self-excludes on install)
- [X] T002 [P] Bump `requires.speckit_version` from `">=0.2.0"` to `">=0.13.0"` in all four `.specify/extensions/*/extension.yml` (research D8 — honest floor)
- [X] T003 [P] Add hook `prompt` fields to every hook entry in the four `extension.yml` manifests, matching the canonical prompts in `.specify/extensions.yml` (closes the last FR-014 metadata field; priorities/descriptions already pinned)

---

## Phase 2: Foundational (blocking — consumer-state correctness before anything ships)

**⚠️ CRITICAL**: T004 changes what US1 packages and what US3 must preserve; T005 is US2's guard.

- [X] T004 Migrate the clickup plug to the CLI's update-protected config convention (research D4 — verified clobber): add `config.defaults` placeholders to `.specify/extensions/clickup/extension.yml`; delete shipped `config.yml`; update read precedence to env (`SPECKIT_CLICKUP_*`) > `local-config.yml` > `clickup-config.yml` > defaults in `commands/speckit.clickup.sync.md` + `commands/speckit.clickup.provision.md`; point the ruleset write in `commands/speckit.clickup.design-rules.md` at `clickup-config.yml` (it writes config too — do not miss it); move this repo's real values `config.local.yml` → `local-config.yml`; update `.gitignore` + `.specify/extensions/clickup/README.md`
- [X] T005 Add the engine-missing runtime guard (FR-008, CLI does not enforce `requires.extensions` — verified): in all three clickup command bodies, before any tracker work, check `.specify/extensions/engine/scripts/bash/` helpers exist; on miss, fail loud naming `specify extension add engine`, zero tracker writes

**Checkpoint**: plug config is update-safe and the dependency gap is guarded — release work can begin

---

## Phase 3: User Story 1 — Maintainer publishes a versioned release (P1) 🎯 MVP

**Goal**: one bump action + one release step → four leak-scanned ZIPs + committed catalog.json + GitHub Release.

**Independent Test**: `release.sh <v> --dry-run` on this repo → four archives, catalog, zero forbidden-content hits, byte-stable re-run (quickstart Scenario 1 step 1).

- [X] T006 [US1] Write `.specify/scripts/bash/release.test.sh` FIRST (must fail before T007): semver validation + strictly-greater-than-last-tag; version stamping + zero-drift check across the four `extension.yml` + `package.json` (five files); file selection honoring `.extensionignore` + exclusion list; catalog generation (fixed inputs → byte-stable JSON, lockstep enforcement, sha256 fields); forbidden-content scan fixtures (planted `local-config.yml` and a real workspace name must abort)
- [X] T007 [US1] Implement the deterministic functions in `.specify/scripts/bash/release.sh` (stamp, drift-check, build_archives, scan_archives, generate_catalog) until `release.test.sh` is green; the gate picks the test up automatically via `run-tests.sh`
- [X] T008 [US1] Implement release orchestration in `.specify/scripts/bash/release.sh`: preflight (clean tree, on `main`, `gh`/`jq`/`zip`/`shasum` present — fail loud), `--dry-run` (side-effect-free; also emits `dist/catalog.local.json` with `http://localhost:<port>` URLs for the offline harness), publish (commit `release: v<version>`, tag, push, `gh release create` with four assets), refuse-existing-tag, idempotent resume after a partial publish (contracts/release.command.md)
- [X] T009 [US1] Dry-run E2E on this repo: run `release.sh 1.0.0 --dry-run` twice → four ZIPs, catalog matches contracts/catalog.schema.md, zero scan hits, byte-identical archives across runs

**Checkpoint**: publishable artifacts exist locally; nothing real published yet

---

## Phase 4: User Story 2 — Consumer installs the whole engine by name (P1) 🎯 MVP

**Goal**: fresh repo → catalog registration → four extensions by name → full command set, canonical wiring, guards intact.

**Independent Test**: quickstart Scenario 1 (offline, localhost catalog) end-to-end.

- [X] T010 [US2] Offline install E2E (quickstart Scenario 1): serve `dist/` via `python3 -m http.server`, fresh `specify init --integration claude` repo, `catalog add … --name snackbyte --install-allowed`, `specify extension add engine clickup git-lifecycle review-loop` → all four at the release version, every command/skill rendered, no local-config anywhere in the install (SC-005 spot-check); record hook wiring for T011/SC-004. Also assert the subset edge case in a second scratch repo: install **only** engine + clickup and run a lifecycle command — no errors from absent-extension hooks (spec Edge Cases)
- [X] T011 [US2] Wiring-fidelity assertion for the T010 install: field-for-field diff (event, extension, command, enabled, optional, priority, prompt, description) between the installed `extensions.yml` and the four manifests — zero differences (SC-004; use T017's helper if already built, else perform and script it there)
- [X] T012 [US2] Dependency-guard E2E (quickstart Scenario 2): fresh repo, install **only** clickup, run its sync → immediate actionable failure naming `specify extension add engine`, zero tracker writes (validates T005)

**Checkpoint**: MVP complete — a stranger with the CLI and the catalog URL can install the working engine

---

## Phase 5: User Story 3 — Consumer updates without hand-migration (P2)

**Goal**: N → N+1 in one action; consumer-owned state byte-identical; pre-release repos have a written way in.

**Independent Test**: quickstart Scenario 3 (offline N+1 update) + the migration doc followed on one real pre-release repo.

- [X] T013 [US3] Update-preservation E2E (quickstart Scenario 3): in the T010 consumer, fill `clickup-config.yml` + `local-config.yml`, disable one hook; rebuild at version+1, clear `.specify/extensions/.cache/`, `specify extension update` → all four at N+1, both config files byte-identical, disabled hook still disabled, per-feature manifests untouched (SC-003)
- [ ] T014 [P] [US3] Write the pre-release migration doc `docs/MIGRATION.md` (FR-013): applies to bed-generators, snackbyte-discord, snackbyte-links — delete old hand-copied extension dir(s) + stale registry entries, move real values `config.local.yml` → `local-config.yml`, catalog-install at 1.0.0 (the pre-release "2.0.0" rewind is inert after reinstall — research D9), keep `.clickup-sync.json` manifests (idempotent reconcile, no duplicate cards). Then **execute the doc** end-to-end on the lowest-stakes of the three repos (quickstart Scenario 6): existing manifests reconcile with 0 duplicate cards, next sync is a no-op

---

## Phase 6: User Story 4 — A friend on GitHub Copilot adopts the engine (P2)

**Goal**: same catalog flow on a Copilot-integration repo; documented path to a live ClickUp connection.

**Independent Test**: quickstart Scenario 5.

- [X] T015 [US4] Copilot install E2E (quickstart Scenario 5): `specify init --integration copilot` scratch repo, catalog-install all four → every command rendered under `.github/prompts/` at parity with the Claude set; hook wiring identical to T010's
- [X] T016 [P] [US4] Write the Copilot section of the consumer guide (FR-015): connecting a ClickUp MCP server in the consumer's environment, then provision + sync against their own workspace — standalone, no source spelunking

---

## Phase 7: User Story 5 — Installed wiring matches curated wiring (P3)

**Goal**: fidelity is mechanically checkable, not eyeballed.

**Independent Test**: helper reports zero diffs on a fresh install; seeded diff is caught.

- [X] T017 [US5] Build `.specify/scripts/bash/wiring-fidelity.sh` + `wiring-fidelity.test.sh` (Constitution V): compare a repo's `extensions.yml` hook entries field-for-field against a set of extension manifests; exit non-zero listing any drift; used by T011 and future releases' self-checks

---

## Phase 8: Polish & Cross-Cutting

- [X] T018 [P] Consumer guide `docs/CONSUMING.md` (FR-015): CLI install (`uv tool install` from a released spec-kit ≥ 0.13), catalog registration with the **required** `--install-allowed` flag, install/update/uninstall, config how-to (`clickup-config.yml` / `local-config.yml` / env), the 1-hour catalog cache (no refresh flag; delete `.specify/extensions/.cache/` to force), what updates replace vs. preserve
- [X] T019 [P] Release runbook `docs/RELEASING.md` (FR-006): bump → `release.sh` → verify → announce; cache-lag note; defects roll forward, never republish a version
- [X] T020 Update root `README.md`: distribution section with the raw catalog URL, the two consumer commands, and the four-extension suite
- [ ] T021 Cut **v1.0.0 for real** (`release.sh 1.0.0` on `main`) and run quickstart Scenario 4 from a clean clone/second machine: register the raw `catalog.json` URL, install all four by name, provision + live sync against a real ClickUp space (SC-001, SC-002, SC-006 first half; closes VALIDATION.md's "consolidated spine in a clean repo")
- [ ] T022 Manual (human-in-the-loop): a friend's Copilot repo completes install → configure → provision → first sync using only the docs (SC-007, SC-006 second half); every needed intervention becomes a documentation fix

---

## Dependencies & Execution Order

- **Setup (P1)** → **Foundational (P2)** → user stories. T004 gates US1 (archives ship the new config shape) and US3 (preservation targets the new names); T005 gates T012.
- **US1 → US2/US3**: install/update E2Es consume US1's artifacts. **US2 → US4** (same harness, other integration). T017 (US5) ideally lands before T011 uses it, but T011 may diff manually and hand the script work to T017.
- **Within US1**: T006 (tests, failing) → T007 (green) → T008 → T009. Test-first is constitutional (Principle V), not optional.
- **Polish**: T018/T019/T014/T016 are docs and parallel-safe [P]; T021 is the last automated task; T022 is the only human-gated one.

## Parallel Opportunities

- Phase 1: T001, T002, T003 all [P] (different files).
- After US1: T013 (US3) and T015 (US4) can run in parallel with each other; docs T014/T016/T018/T019 all [P].

## Implementation Strategy

**MVP = Phase 1 + 2 + US1 + US2** (the two P1 stories are jointly the MVP per spec): after T012, the engine is installable-by-name from a local catalog and the release machinery is proven. Then US3 (update) → US4 (Copilot) → US5 (fidelity helper) → Polish → the real v1.0.0 cut (T021) → friend validation (T022).
