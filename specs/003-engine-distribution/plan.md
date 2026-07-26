# Implementation Plan: Engine Distribution — versioned, catalog-installable releases

**Branch**: `003-engine-distribution` | **Date**: 2026-07-24 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/003-engine-distribution/spec.md`

## Summary

Turn the four-extension engine suite into a versioned library: a maintainer-run `release.sh`
stamps one lockstep version across all extensions, builds leak-scanned ZIP archives, regenerates
`catalog.json`, and publishes a GitHub Release; consumers register the raw-URL catalog once and
then install/update by name with the stock `specify extension` commands on Claude Code or GitHub
Copilot repos. Two consumer-breaking gaps found in research are closed as part of this feature:
the plug's config moves to the CLI's update-protected naming (`clickup-config.yml` +
`local-config.yml` — plain `config.yml` is verifiably clobbered on update), and every
`extension.yml` hook entry gains the curated `prompt`/`priority`/`description` metadata so fresh
installs reproduce the canonical wiring. All substrate mechanics were verified live against
specify 0.13.5-dev (see [research.md](research.md)).

## Technical Context

**Language/Version**: Bash (release tooling + unit tests, matching the existing
`scripts/bash` + `*.test.sh` house pattern); YAML/JSON for manifests and the catalog; Markdown
for command prompts and consumer docs. No new languages.

**Primary Dependencies**: upstream `specify` CLI ≥ 0.13 (consumer side — the whole install/
update substrate); maintainer-side release preflight hard-requires `gh`, `jq`, `zip`,
`shasum`/`sha256sum` (fail-loud check, no fallbacks — release is maintainer-only tooling).

**Storage**: files only — four extension source dirs, `catalog.json` at repo root, GitHub
Release assets; consumer side uses the CLI-owned `.specify/extensions/.registry` and
`extension-catalogs.yml`.

**Testing**: existing bash harness (`npm run check:all` → `run-tests.sh`); new
`release.test.sh` covers the deterministic release functions (version stamping/consistency,
file selection/exclusions, catalog generation, forbidden-content scan). Publish orchestration
(gh/network) is validated via quickstart, per Constitution V's split.

**Target Platform**: maintainer on macOS/Linux; consumers on anything the specify CLI supports
(the shipped extensions remain bash + markdown; no new runtime requirements for consumers).

**Project Type**: distribution/packaging tooling for an existing Spec Kit extension suite
(no application code).

**Performance Goals**: n/a beyond spec SCs — install ≤ 3 commands / < 5 min (SC-001); release =
1 bump action + 1 release step (SC-002).

**Constraints**: no node package / npm publish (constitution); catalog URL must be HTTPS and
never move ("register once"); published releases immutable — defects roll forward; catalog cache
TTL 3600 s with no CLI refresh flag (documented consumer behavior); CLI does not enforce
`requires.extensions` (plug-side runtime guard required); CLI replaces shipped files on update
(hard shipped-vs-owned line in docs).

**Scale/Scope**: 4 extensions, ~30 KB/archive; consumers: maintainer's other repos + friends'
repos (single-digit). 3 pre-release hand-copied installs to migrate.

## Constitution Check

*GATE: evaluated pre-Phase-0 and re-checked post-design — PASS on both.*

| Principle | Verdict | Note |
|---|---|---|
| I. One-way, repo is source of truth | PASS | Distribution never touches trackers; release flows repo → artifacts. |
| II. Plugs own all tracker I/O | PASS | Release tooling and catalog carry no tracker I/O, credentials, or IDs; config files ship as placeholders/defaults only. |
| III. Idempotent | PASS | Same-version re-release refuses (tag exists); catalog generation is deterministic from inputs; consumer re-install over same version is CLI-guarded (verified). |
| IV. Scaffolding-only | PASS | Everything lands under `.specify/` (+ agent command dirs written by the CLI) in consumer repos; `catalog.json` + release script live in the engine repo only. |
| V. Deterministic logic is tested (non-negotiable) | PASS | All deterministic release functions get `release.test.sh` in the existing gate; only the thin gh/network publish step is quickstart-validated, mirroring the tested-bash vs. orchestration split. |
| VI. Plugs are additive (zero/one/many) | PASS | Catalog installs any subset; missing-extension hooks are absent, not errors (verified: subset installs work); dependency gap closed by plug-side guard, not coupling. |
| No-node-package constraint | PASS | ZIPs + JSON catalog + gh release; root `package.json` remains check-gate-only and is never published. |

No violations → Complexity Tracking not applicable.

## Project Structure

### Documentation (this feature)

```text
specs/003-engine-distribution/
├── plan.md              # This file
├── research.md          # Phase 0 — verified substrate mechanics + 10 decisions
├── data-model.md        # Phase 1 — release/catalog/config entities & transitions
├── quickstart.md        # Phase 1 — offline E2E harness + live release validation
├── contracts/
│   ├── release.command.md        # release.sh contract (preflight, steps, failures)
│   ├── catalog.schema.md         # catalog.json schema + hosting + cache semantics
│   └── extension-packaging.md    # what ships in a ZIP; hook metadata; config naming
└── tasks.md             # Phase 2 (/speckit-tasks — not created here)
```

### Source Code (repository root)

```text
.specify/
├── scripts/bash/
│   ├── release.sh                # NEW — the one release action (stamp/gate/build/publish)
│   └── release.test.sh           # NEW — unit tests for its deterministic functions
├── extensions/
│   ├── engine/extension.yml      # EDIT — hook metadata n/a (no hooks); version floor 0.13
│   ├── clickup/
│   │   ├── extension.yml         # EDIT — hook prompt/priority/description; floor; defaults
│   │   ├── .extensionignore      # NEW — excludes local config, caches (self-excluding)
│   │   ├── config.yml            # REMOVED from shipping (replaced by CLI config convention)
│   │   └── commands/*.md         # EDIT — read local-config.yml > clickup-config.yml; engine guard
│   ├── git/extension.yml         # EDIT — hook metadata + floor
│   └── review-loop/extension.yml           # EDIT — hook metadata + floor (merged from
│                                           #   specify-review-loop + analyze-autofix, 2026-07-26)
├── extensions.yml                # EDIT — reconcile stale ids/commands (canonical wiring)
catalog.json                      # NEW — generated by release.sh, committed on main
docs/ (or README section)         # NEW — consumer install/update/migration guide (FR-015)
```

**Structure Decision**: no new top-level trees. Release tooling joins the existing tested-bash
home (`.specify/scripts/bash/`); all shipping changes live inside the four existing extension
dirs; `catalog.json` is the only new root file (its raw URL is the consumers' registration
point, so its path must never change).
