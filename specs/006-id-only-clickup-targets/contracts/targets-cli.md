# Contract: `targets.sh` (ClickUp plug, ships in the extension)

Path: `.specify/extensions/clickup/scripts/bash/targets.sh`. Pure repo-side; makes no ClickUp
calls.

## `targets.sh resolve [--config-dir DIR]`

Reads the layered config (see clickup-config.md). `DIR` defaults to the extension directory.

stdout is one JSON object; exit code as below.

| Exit | `status` | Shape |
|---|---|---|
| 0 | `ready` (existing list) | `{"status":"ready","path":"existing","workspaceId":"…","spaceId":"…","listId":"…"}` |
| 0 | `ready` (create) | `{"status":"ready","path":"create","workspaceId":"…","spaceId":"…","folderId":"…","newListName":"…"}` |
| 0 | `disabled` | `{"status":"disabled"}`. `enabled: false`; the caller exits silently |
| 0 | `unconfigured` | `{"status":"unconfigured"}`. No location key, name key or `new-list-name` set anywhere; the caller runs ask-once |
| 1 | `invalid` | `{"status":"invalid","errors":["<key>: <message>", …]}`. The same lines go to stderr |
| 2 | — | Usage error |

Guarantees:
- No name value ever appears in a `*Id` field.
- `newListName` appears only on the create path.

## `targets.sh pin-list --id ID [--config-dir DIR]`

Rewrites `DIR/clickup-config.yml` in place: the single top-level `new-list-name: "<name>"` line
becomes `list-id: "ID"  # <name>`. Every other byte is unchanged.

| Exit | When |
|---|---|
| 0 | Pinned. Prints `pinned list-id ID (<name>) in <path>` |
| 1 | `ID` not numeric; `list-id` already set in the file; no `new-list-name` line; file missing |
