---
description: "Locate the pinned ClickUp list by ID (or create it in the pinned folder and pin it), then record the target IDs and status mapping in the active feature's manifest"
---

# ClickUp Sync — Provision

Record where this feature's ClickUp card lives, so later `sync` runs never have to discover or
guess. Provisioning runs once per feature, before sync. After a repo's first feature it is a pure
reuse of the pinned list. All ClickUp access goes through the connected ClickUp MCP server; the
plug has no API or auth code of its own.

**Containers are located by ID only.** The workspace, space, folder and list come from the `*-id`
keys in config. Names are comments for humans: a name is never a lookup, and no step browses the
hierarchy or passes a name to a ClickUp tool. **Every ClickUp call passes `workspace_id`.**

The one stated exception is **statuses**, which are mapped by name. ClickUp sets a task's status by
its name, and names are only ever resolved inside the list already located by ID, where status
names are unique.

## Preconditions

- **The engine extension is installed**: `.specify/extensions/engine/scripts/bash/manifest.sh`
  exists. If not, **stop immediately with zero tracker writes**: "The clickup plug requires the
  engine extension. Install it: `specify extension add engine`."
- The ClickUp MCP server is connected.

## Resolve the target (no ClickUp calls)

```bash
.specify/extensions/clickup/scripts/bash/targets.sh resolve
```

The script applies the layered config (env `SPECKIT_CLICKUP_<KEY>` > `local-config.yml` >
`clickup-config.yml` > shipped defaults) and the ID-only rules. Act on its `status`:

- **`disabled`**: the repo declined ClickUp sync. **Silently do nothing and exit 0.** Do not ask
  again.
- **`invalid`** (exit 1): **stop with zero ClickUp calls.** Print every line of `errors` as-is.
  Each one names the key to set. Point to the plug README's *Configure* section (where each ID is
  visible in ClickUp) and to `docs/MIGRATION.md` for a name-based config.
- **`unconfigured`**: nothing is set yet. **Ask the user once**: "This repo isn't wired to ClickUp
  yet. Give me the workspace ID and space ID, plus either the list ID, or a folder ID and a name
  for a new list there. Or say you don't want ClickUp sync here. (A list's URL is
  `app.clickup.com/<workspace-id>/v/l/li/<list-id>`; a space's or folder's ID is in its URL.)"
  - **If they give IDs**: write them to **`clickup-config.yml`** as `workspace-id`, `space-id`,
    and `list-id` (or `folder-id` + `new-list-name`). Put any names they mention in comments.
    Re-run `targets.sh resolve`. If it is still `invalid`, stop and print its errors; do not
    re-prompt.
  - **If they decline**: set `enabled: false` in `clickup-config.yml` with a short note, then exit
    0. Never ask again.
  - Ask **once per run**.
- **`ready`**: proceed with its `workspaceId`, `spaceId`, and either `listId` (`path: existing`)
  or `folderId` + `newListName` (`path: create`).

## Steps

1. **Resolve the active feature** and manifest path:

   ```bash
   .specify/extensions/engine/scripts/bash/manifest.sh path
   ```

2. **Locate or create the list, by ID**:
   - **`path: existing`**: call `clickup_get_list` with `list_id` = `listId` and `workspace_id` =
     `workspaceId`. If ClickUp reports it not found, **stop** and print `list-id: <listId> not
     found in workspace <workspaceId>`. Otherwise keep the response; its statuses feed step 3.
   - **`path: create`**:
     1. Call `clickup_get_folder` with `folder_id` = `folderId` and `workspace_id`. If ClickUp
        reports it not found, **stop** and print `folder-id: <folderId> not found in workspace
        <workspaceId>`.
     2. Call `clickup_create_list_in_folder` with `folder_id` = `folderId`, `name` =
        `newListName` and `workspace_id`. Record the new list's ID.
     3. **Pin it immediately**, before any other ClickUp write:

        ```bash
        .specify/extensions/clickup/scripts/bash/targets.sh pin-list --id <new list id> --name "<newListName>"
        ```

        This rewrites `new-list-name` in `clickup-config.yml` to `list-id: "<id>"  # <name>`,
        so every later feature reuses the list by ID. If the pin fails, **stop with no further
        ClickUp writes**. Print the new list's ID and the exact line to add:
        `list-id: "<id>"  # <name>`.
     4. Call `clickup_get_list` with the new `list_id` and `workspace_id` to read its statuses.

   Make no other checks. The configured IDs are authoritative.

3. **Resolve the six-state status mapping**, by name within this list (the stated exception).
   Map the engine's six logical states onto the list's real status names:
   `open · in-design · ready · in-development · in-review · done`.
   - **Prefer the merged config's `statuses:` block** if present. It names the actual status for
     each logical state. Every named status must exist on the list; if one doesn't, **stop** and
     name the mismatch.
   - **Otherwise resolve a best-effort mapping** from the list's real statuses: an open-type
     status → `open`, a done/closed-type → `done`, distinct middle statuses → the in-between
     states in order.
   - **Degrade, don't fail**. A list without six distinct statuses maps to the three-state floor
     (not-started / in-progress / done), using `status-map.sh` semantics:
     - `open`/`in-design`/`ready` → the open status
     - `in-development`/`in-review` → a middle status
     - `done` → the done status

     **Stop** only if the list cannot represent three distinct states, naming what it needs.

4. **Write the manifest targets** from the resolved IDs (merge, preserving any existing
   `card`/`userStories`):

   ```bash
   .specify/extensions/engine/scripts/bash/manifest.sh set-targets \
     --workspace "<workspaceId>" --space "<spaceId>" --list "<list id>" \
     --status-map '{"open":"<name>","in-design":"<name>","ready":"<name>","in-development":"<name>","in-review":"<name>","done":"<name>"}'
   ```

5. **Create the feature-card in `open`** (FR-013a), so the `open → in-design` transition at
   `/speckit-specify` is itself visible as "design work started".
   - Derive the desired state with `derive-status.sh --card`. With no spec yet this yields `open`.
   - Map it with `status-map.sh resolve --logical open --map <statusMapping>`.
   - Call `clickup_create_task` with `list_id` = the list, `workspace_id`, `name` = the feature
     title, a minimal body, and `status` = the mapped `open` status.
   - Record it: `manifest.sh set-card --id <id> --hash <hash>` (hash the derived card content per
     the sync contract).
   - If a `card.id` already exists in the manifest, this is a re-provision: do NOT create a
     second card.

6. **Report**:
   - the list used (ID; "pinned" when the create path made it)
   - the resolved six-state (or degraded three-state) mapping
   - the card created in `open`

   Or report the stop-reason. When the create path pinned a list, say that
   `clickup-config.yml` changed and is committed with the spec at the pre-implementation
   checkpoint.

## Idempotence

Re-running uses the same IDs and rewrites the same target values. The create path runs at most
once per repo: after the pin, `targets.sh resolve` returns `path: existing`.

## Never

- Never locates a container by name, never browses the workspace hierarchy, and never passes a
  name argument to a ClickUp tool. `id-only-guard.sh` enforces this in the check gate.
- Never creates a space or a folder, and never creates a list outside the pinned folder.
- Never writes to the repo other than the feature manifest and its own plug config (the ask-once
  write and the list pin).
- Never touches unrelated cards or tasks in the list.
- Never proceeds past an invalid config, a not-found ID, or an insufficient status set: it stops.
