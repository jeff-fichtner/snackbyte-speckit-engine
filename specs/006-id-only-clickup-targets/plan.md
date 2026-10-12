# Implementation Plan: ID-only ClickUp targets

**Branch**: `006-id-only-clickup-targets` | **Date**: 2026-10-11 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/006-id-only-clickup-targets/spec.md`

## Summary

Config resolution moves out of the provision prompt into a tested script,
`.specify/extensions/clickup/scripts/bash/targets.sh`. It reads the layered config, applies the
ID-only rules (required keys, name-without-ID error, numeric IDs, existing-list vs create path),
and prints a resolved target as JSON, or fails listing every offending key. It also owns the pin
rewrite after a list is created.

The provision, sync and design-rules prompts are rewritten to:
- consume the script's resolved target
- address ClickUp only through ID-addressed MCP tools, always passing `workspace_id`
- never browse the hierarchy or pass a `*_name` argument

A repo-level guard script, wired into the check gate through its test, fails on any regression. It
catches a `*_name` argument, a tool outside the ID-addressed allowlist, a config name key read as a
locator, or a command that calls ClickUp without `workspace_id`.

Other changes:
- git-lifecycle's pre-implement checkpoint also commits changed repo-level extension config, so a
  pin reaches the branch.
- Constitution II and IV are amended (v3.0.0).
- Docs, skill mirrors, the release scan and this repo's own config follow.

## Technical Context

**Language/Version**: Bash 3.2+ (macOS system bash) and POSIX awk/sed. Markdown command prompts.

**Primary Dependencies**: `jq` (already required by `manifest.sh`), git, the connected ClickUp
MCP server (claude.ai connector) at runtime.

**Storage**: Flat YAML config files (`clickup-config.yml`, `local-config.yml`, legacy names) and
the per-feature JSON manifest (unchanged shape).

**Testing**: `*.test.sh` discovered by `.specify/scripts/bash/run-tests.sh` (`npm run check:all`).
Live validation against the real ClickUp workspace per `quickstart.md`.

**Target Platform**: Developer machines running Spec Kit ≥0.13 with Claude Code (or another
agent) and a ClickUp MCP connection.

**Project Type**: Spec Kit extensions (markdown commands + bash helpers).

**Performance Goals**: N/A. Provision makes at most 3 ClickUp reads + 2 writes on the create path.

**Constraints**:
- No name-based container lookup anywhere in the plug.
- Zero tracker writes before config validation and live ID verification both pass.
- No silent defaults for location keys.

**Scale/Scope**: 3 plug commands, 3 skill mirrors, 1 new plug script + test, 1 new repo guard +
test, 1 git-lifecycle script change + test, constitution, 4 docs, release scan list, this repo's
config.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Note |
|---|---|---|
| I. One-way | ✅ | Unchanged. The pin writes plug config (repo-side, plug-owned), never a spec artifact, and is derived from the plug's own create, not from tracker state edited by a human. |
| II. Plugs own tracker I/O; config names WHERE | ⚠️ → amended | Config now identifies WHERE **by ID**. Still no secrets. Amended per FR-017 (agreed in Clarifications). |
| III. Idempotent | ✅ | The pinned ID makes the 2nd+ provision a pure reuse. The create path runs once per repo. |
| IV. Scaffolding-only; IDs only in manifest | ⚠️ → amended | Container IDs now also live in the plug's committed config. Amended per FR-017. Still nothing in shipped app source/CI. |
| V. Deterministic logic tested | ✅ | Resolution, validation, pin rewrite, guard and checkpoint scope all land as scripts with `*.test.sh`. The prompt keeps only MCP orchestration. |
| VI. Additive | ✅ | Unchanged. `enabled: false` and an uninstalled plug stay no-ops. |
| VII. Earned handoff | ✅ | Plan includes the live E2E in quickstart.md, with cleanup. |
| Config-only retargeting | ✅ | Retargeting = edit IDs in config. |

Gate passes **with the amendment as part of this feature** (FR-017), not as a waiver. Post-design
re-check: no new violations.

## Project Structure

### Documentation (this feature)

```text
specs/006-id-only-clickup-targets/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── clickup-config.md        # the config contract (keys, rules, errors)
│   ├── targets-cli.md           # targets.sh subcommands, output, exit codes
│   └── id-only-guard.md         # what the check-gate guard forbids
└── tasks.md
```

### Source Code (repository root)

```text
.specify/
├── memory/constitution.md                                  # II + IV amended → 3.0.0
├── scripts/bash/
│   ├── id-only-guard.sh                                    # NEW repo guard (dev apparatus)
│   ├── id-only-guard.test.sh                               # NEW fixtures + real-repo run
│   └── release.sh                                          # FORBIDDEN_CONTENT += current IDs
└── extensions/
    ├── clickup/
    │   ├── clickup-config.yml                              # this repo: pinned by ID
    │   ├── extension.yml                                   # provision command description
    │   ├── README.md                                       # Configure / State
    │   ├── commands/speckit.clickup.provision.md           # rewritten: ID-only
    │   ├── commands/speckit.clickup.sync.md                # workspace_id on every call
    │   ├── commands/speckit.clickup.design-rules.md        # inspect pinned list by ID
    │   └── scripts/bash/
    │       ├── targets.sh                                  # NEW resolve / pin-list
    │       └── targets.test.sh                             # NEW
    └── git-lifecycle/scripts/bash/
        ├── commit-spec-artifacts.sh                        # + changed *-config.yml
        └── commit-spec-artifacts.test.sh                   # NEW
.claude/skills/speckit-clickup-{provision,sync,design-rules}/SKILL.md   # mirrors
docs/CONSUMING.md, docs/MIGRATION.md, README.md                         # ID contract + migration
```

**Structure Decision**: The resolver ships **inside the clickup extension** (`scripts/bash/`),
because consumers run it at provision. The guard is **repo apparatus** (`.specify/scripts/bash/`)
and never ships, per docs/EXPORT-BOUNDARY.md: it checks this repo's source, not a consumer's.

## Complexity Tracking

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Constitution II/IV amended (IDs in committed config) | The ruling: containers are located by ID, pinned in config | Keeping IDs manifest-only forces every new feature to *find* the list again, by name: the bug. |
| git-lifecycle checkpoint widened to extension config | A pin that is never committed is lost on the next branch, so the next feature creates a second list | "Tell the user to commit it" relies on memory; the ask-once write already has this hole today. |
