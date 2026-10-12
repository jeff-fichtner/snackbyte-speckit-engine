---
description: "Stage and commit the current feature's Spec Kit artifacts as a pre-implementation checkpoint"
---

# Commit Spec Artifacts

Capture the current feature's Spec Kit planning state in git history before
implementation begins. This stages the feature's spec directory
(`specs/<feature>/`: `spec.md`, `plan.md`, `tasks.md`, `research.md`,
`data-model.md`, `contracts/`, checklists, etc.). It also stages any repo-level
extension config the lifecycle changed: `.specify/extensions/*/*-config.yml`, such
as a list ID a tracker plug pinned at provision. It commits all of that as one clean
checkpoint and leaves any unrelated working-tree changes untouched.

## Behavior

- Resolves the active feature directory via the core `get_feature_paths()`
  helper (honors `SPECIFY_FEATURE_DIRECTORY` / `.specify/feature.json`).
- Stages `specs/<feature>/` plus modified or new `.specify/extensions/*/*-config.yml`.
  It never stages `local-config.yml` (machine-local) or anything gitignored.
- If none of those paths is dirty, exits successfully as a no-op. It never creates
  an empty commit.
- Otherwise commits with the message
  `chore(spec): checkpoint <feature> artifacts before implement` (override with
  `--message`).

## Execution

- **Bash**: `.specify/extensions/git/scripts/bash/commit-spec-artifacts.sh [--json] [--message "msg"]`

Run from anywhere inside the repo. Add `--json` for machine-readable output
(`{"status": "...", "message": "..."}` where status is `committed`,
`nothing-to-commit`, or `error`).
