# Research: ID-only ClickUp targets

All findings below were checked against the live workspace on 2026-10-11 (read-only), unless
marked otherwise.

## R1 — The live hierarchy makes name lookup unsafe, not just theoretically ambiguous

- **Finding**: workspace `90141363864` has space `products` with **14** lists named `Roadmap`
  (one per product folder) and space `platforms` with **6**. A name lookup in either space has no
  correct answer.
- **Decision**: no lookup by name at any level (the ruling). Backlog 006's sketch (a `folder`
  *name* key + an ambiguity guard) is superseded. It narrowed the search but still searched.

## R2 — Every MCP call needs `workspace_id`

- **Finding**: the account sees six workspaces. `clickup_get_workspace_hierarchy`,
  `clickup_get_list` and `clickup_get_operators` called without `workspace_id` all error ("Multiple
  workspaces available"). Today's provision step 3 calls the hierarchy without it, so it cannot
  run at all on this account.
- **Decision**: `workspace-id` is required config. Every plug MCP call passes it (provision from
  config, sync from the manifest's `workspaceId`). FR-010.

## R3 — Which MCP tools are ID-addressed

| Tool | Addressed by | Allowed |
|---|---|---|
| `clickup_get_list` | `list_id` (also accepts `list_name`) | ✅ with `list_id` only |
| `clickup_get_folder` | `folder_id` (also accepts `folder_name` + `space_name`) | ✅ with `folder_id` only |
| `clickup_create_list_in_folder` | `folder_id` | ✅ |
| `clickup_create_task` / `update_task` / `get_task` | `list_id`, `parent`, `task_id` | ✅ |
| `clickup_add_task_dependency` / `remove_task_dependency` | task IDs | ✅ |
| `clickup_get_custom_fields` | list ID | ✅ |
| `clickup_get_workspace_hierarchy` | browses; matching happens on names | ❌ |
| `clickup_create_list` | `space_id` **or `space_name`**, space-level | ❌ (create only in a folder) |
| `clickup_search` | free text | ❌ |

- **Decision**: the guard enforces this allowlist and bans the `*_name` parameters outright.

## R4 — List-in-folder membership cannot be checked without browsing

- **Finding**: `clickup_get_list` returns `space` but no `folder`. `clickup_get_folder` returns
  its `space` but no lists. The only ID-based membership check is the hierarchy, which R3 bans.
- **Decision**: on the existing-list path the list ID is authoritative and `folder-id` is unused.
  The only live check is that the list exists.
- **Resolved by Jeff (2026-10-11)**: a mistyped ID is not something to defend against. The
  space cross-check and the retarget guard were dropped on the same principle.

## R5 — Status by name is the API's model; status IDs exist but are read-only metadata

- **Finding**: `clickup_get_list` returns statuses with IDs (e.g. `p90146747064_N19bHmf7`,
  space-prefixed). The update/create task tools take `status` as a string "valid for the task's
  list", and ClickUp's v2 task API sets status by name.
- **Decision**: status mapping stays by name, scoped to the ID-located list (FR-011). The live E2E
  also tries setting a status by its ID on a scratch task, to check whether the stated exception
  is necessary (quickstart Scenario 6). Its result is recorded in VALIDATION evidence.

## R6 — This repo's own target is gone

- **Finding**: space `90146433590` and list `901417991049` (002/003 manifests) return "not found".
  The workspace was reorganised into `platforms / speckit-engine / Roadmap`.
- **Decision**: re-pin this repo by ID (FR-020). Closed features 002/003 keep their stale
  manifests (they never sync again). The release scan keeps the old IDs and adds the new ones
  (FR-019).

## R7 — Where the pin lives, and how it gets committed

- **Decision**: the pin is written into the committed `clickup-config.yml`. `new-list-name:
  "<name>"` becomes `list-id: "<id>"  # <name>`, a one-line rewrite owned by `targets.sh
  pin-list`.
- **Alternatives rejected**:
  - *Read the previous feature's manifest*: that is finding it again, and the source is ambiguous
    when there are several manifests.
  - *A separate pin file*: a second place to look, and still needs committing.
  - *Only the manifest*: the manifest is per-feature, so the next feature cannot see it without a
    lookup.
- **Persistence**: `commit-spec-artifacts.sh` (git-lifecycle, `before_implement`) already stages
  `specs/<feature>/` only. It is widened to also stage modified or untracked committed extension
  config (`.specify/extensions/*/*-config.yml`, excluding `local-config.yml` and anything
  gitignored). The rule is generic: git-lifecycle learns no ClickUp specifics.
  `before_specify` already requires a clean tree, so any such change was made by the lifecycle.

## R8 — Deleting test containers

- **Finding**: the connected MCP has no list/folder delete and no operator catalog
  (`clickup_get_operators` → none enabled). Jeff's self-hosted MCP (`~/mcp-server/clickup-stdio.js`,
  Keychain token) has `clickup_delete_list` and can be driven over stdio from a shell.
- **Decision**: E2E tasks are deleted with the connected MCP. The single E2E list is deleted with
  the self-hosted MCP after Jeff confirms its ID.

## R9 — Config parsing in bash

- **Decision**: a flat reader for top-level `key: value` lines only. It strips an unquoted
  trailing `# comment`, strips surrounding quotes, and ignores indented lines (the `statuses:`
  block stays agent-read, as today). Layering is env `SPECKIT_CLICKUP_<KEY>` (`-`→`_`,
  uppercased) > `local-config.yml` > `clickup-config.yml` > `extension.yml` `config.defaults`.
  Legacy `config.local.yml`/`config.yml` are read only when neither new file exists (existing
  grace rule). `<...>` placeholders count as absent.
