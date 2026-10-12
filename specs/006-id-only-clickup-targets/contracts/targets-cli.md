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

## `targets.sh pin-list --id ID --name NAME [--config-dir DIR]`

Pins the created list in the committed layer `resolve` reads: `DIR/clickup-config.yml`, or the
legacy `config.yml` in migration-grace mode. The file is created if missing.
- If the file has a top-level `new-list-name:` line, that line becomes `list-id: "ID"  # NAME`.
- Otherwise (the name came from env or `local-config.yml`), `list-id: "ID"  # NAME` is appended.

Every other byte is unchanged, and the file keeps its mode. A blank or `<...>` `list-id` line
never shadows the pin, because the reader takes the last *real* value.

| Exit | When |
|---|---|
| 0 | Pinned. Prints `pinned list-id ID (NAME) in <path>` |
| 1 | `ID` not numeric; `list-id` already set |
