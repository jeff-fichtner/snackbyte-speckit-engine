# Quickstart: validating ID-only ClickUp targets

Live scenarios run against workspace `90141363864`. Scenarios 1–3 are read-only apart from one
card that Scenario 6 deletes. Every write in Scenarios 1, 4 and 5 is cleaned up
in Scenario 6.

## Prerequisites

- On branch `006-id-only-clickup-targets`; `npm run check:all` green.
- The ClickUp MCP connected (claude.ai connector). For Scenario 6 only, Jeff's self-hosted MCP
  (`~/mcp-server/clickup-stdio.js`), which has `clickup_delete_list`.
- A scratch feature directory outside `specs/` of any real feature, used with
  `manifest.sh --dir` so no real manifest is touched.

## Scenario 0 — the gate (US4)

`npm run check:all` passes. Temporarily add `list_name` to a ClickUp call line in
`speckit.clickup.provision.md`: the gate fails with `…provision.md:<line>: G1`. Revert: green.

## Scenario 1 — karaoke provisions into 901421288946 (US1, SC-002)

1. Scratch config dir with karaoke's pinned IDs: `workspace-id 90141363864`, `space-id
   90146746995`, `list-id 901421288946`, plus karaoke's `statuses:` block.
2. `targets.sh resolve --config-dir <scratch>` → `ready/existing`, `listId 901421288946`.
3. `clickup_get_list(list_id=901421288946, workspace_id=…)` → `space.id 90146746995`. Statuses
   contain every mapped name.
4. `manifest.sh --dir <scratch feature> set-targets …`. Then `clickup_create_task` in
   `901421288946` (status `backlog`), named `E2E 006 — delete me`.
5. Expect: manifest `listId` = `901421288946`. The card's list is `901421288946`
   (`clickup_get_task`). No hierarchy call was made.

## Scenario 2 — name-only config fails loudly (US2, SC-003)

`targets.sh resolve --config-dir <copy of karaoke's current clickup-config.yml>` → exit 1. Errors
name `workspace-id`, `space` / `space-id` and `list` / `list-id`. No ClickUp call is possible (the
script makes none, and provision stops on `invalid`).

## Scenario 3 — a dead list ID is caught live (US2 AS4)

Config with `list-id 901417991049` (this repo's old, deleted list) → `get_list` not found →
provision stops naming `list-id 901417991049`.

## Scenario 4 — create path pins the new list (US3, SC-004)

1. Scratch config: `workspace-id 90141363864`, `space-id 90146747064`, `folder-id 901411097129`
   (platforms / speckit-engine), `new-list-name "speckit-engine-e2e-delete-me"`.
2. `resolve` → `ready/create`. `clickup_get_folder(901411097129)` → space `90146747064`.
3. `clickup_create_list_in_folder(folder_id=901411097129, name=…)` → `<new id>`.
4. `targets.sh pin-list --id <new id> --config-dir <scratch>`. The config now has
   `list-id: "<new id>"  # speckit-engine-e2e-delete-me`, and `new-list-name` is gone.
5. `resolve` again → `ready/existing` with `<new id>`. Provision a second scratch feature: no
   list is created, and its manifest `listId` = `<new id>`. Create its card (for Scenario 5).

## Scenario 5 — is status-by-name actually required? (FR-011 check)

On the Scenario 4 card: `clickup_update_task(status=<a status ID from get_list>)`. Record whether
ClickUp accepts an ID or rejects it. Then set it by name and confirm the read-back.

## Scenario 6 — cleanup (SC-005)

1. `clickup_delete_task` for each E2E card; confirm each with a `clickup_get_task` not-found
   read-back.
2. Jeff confirms the exact list ID from Scenario 4. Then delete it through the self-hosted MCP:
   `clickup_delete_list(list_id)`. Read back with `clickup_get_list` → not found.

## Scenario 7 — the pin reaches the commit (US3 AS3)

Covered by `commit-spec-artifacts.test.sh`, in a throwaway git repo:
- a modified `clickup-config.yml` is included in the checkpoint commit
- `local-config.yml` and unrelated files are not
