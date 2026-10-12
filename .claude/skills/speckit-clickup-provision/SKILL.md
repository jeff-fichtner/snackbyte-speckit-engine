---
name: "speckit-clickup-provision"
description: "Locate the pinned ClickUp list by ID (or create it in the pinned folder and pin it), then record the target IDs and status mapping in the active feature's manifest."
argument-hint: "(no arguments)"
compatibility: "Requires spec-kit project structure with .specify/ directory and the ClickUp MCP server connected"
metadata:
  author: "snackbyte"
  source: ".specify/extensions/clickup/commands/speckit.clickup.provision.md"
user-invocable: true
disable-model-invocation: false
---

Execute the ClickUp provision command. The authoritative command body lives at
`.specify/extensions/clickup/commands/speckit.clickup.provision.md`. Read it and follow its
steps exactly.

Record where this feature's ClickUp card lives, by ID only. Containers come from the `*-id` keys in
`clickup-config.yml`; names are comments and are never looked up. Every ClickUp call passes
`workspace_id`. Statuses are the one stated exception: they are mapped by name inside the list
located by ID.

## Steps

1. Read the full command body at
   `.specify/extensions/clickup/commands/speckit.clickup.provision.md`.
2. Run `.specify/extensions/clickup/scripts/bash/targets.sh resolve` and act on its `status`:
   - `disabled`: silent no-op.
   - `invalid`: stop with zero ClickUp calls and print its errors, which name the keys.
   - `unconfigured`: ask once for IDs, or record a decline as `enabled: false`.
   - `ready`: proceed.
3. Follow the command verbatim:
   - `path: existing`: `clickup_get_list` by `list_id` + `workspace_id`.
   - `path: create`: `clickup_get_folder` by `folder_id`, then `clickup_create_list_in_folder`,
     then `targets.sh pin-list` immediately.
   - Then: map statuses by name, `manifest.sh set-targets`, and create the card in `open` with
     `clickup_create_task` (`list_id`, `workspace_id`).
4. Stop on a not-found ID, a failed pin, or a list whose statuses cannot represent three states,
   naming exactly what is wrong. Make no other cross-checks.

## Done When

- [ ] The command body was read and followed step by step.
- [ ] No container was located by name; every ClickUp call passed `workspace_id`.
- [ ] The manifest records the resolved IDs and status mapping (or the run stopped with a clear reason).
