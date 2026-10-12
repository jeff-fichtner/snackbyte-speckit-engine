# Data Model: ID-only ClickUp targets

## Plug config (merged view)

Fields and validation are in [contracts/clickup-config.md](contracts/clickup-config.md).
Layers, highest first:

1. env `SPECKIT_CLICKUP_<KEY>`
2. `local-config.yml`
3. `clickup-config.yml`
4. `extension.yml` defaults

`<...>` counts as absent.

## Resolved target (output of `targets.sh resolve`)

```
status:      ready | disabled | unconfigured | invalid
path:        existing | create                    (ready only)
workspaceId: digits                               (ready)
spaceId:     digits                               (ready)
listId:      digits                               (path=existing)
folderId:    digits                               (path=create)
newListName: text                                 (path=create)
errors:      [ "<key>: <message>" ]               (invalid)
```

Invariant: every `*Id` is digits-only and came from a `*-id` key. A name never reaches an `*Id`.

## Config lifecycle (create path)

```
{ folder-id, new-list-name }  ──provision creates list──▶  { folder-id, list-id }   (pinned)
          path=create                                        path=existing (every later run)
```

The transition is the `pin-list` rewrite. It is one-way: nothing rewrites `list-id` back.

## Feature manifest (`specs/<feature>/.clickup-sync.json`)

Shape unchanged. `workspaceId`, `spaceId` and `listId` are now copied from the resolved target,
not discovered. Sync reads `workspaceId` to pass `workspace_id` on every call.

## Live verification (provision, before any write)

| Path | Read | Must hold | Else stop naming |
|---|---|---|---|
| existing | `clickup_get_list(list_id, workspace_id)` | found | `list-id` + the ID |
| create | `clickup_get_folder(folder_id, workspace_id)` | found | `folder-id` + the ID |

No cross-checks between keys (Clarifications: no defensive cross-checks).
