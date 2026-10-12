# Contract: `id-only-guard.sh` (repo apparatus — never ships)

Path: `.specify/scripts/bash/id-only-guard.sh`. Run by `id-only-guard.test.sh` inside
`npm run check:all`.

```
id-only-guard.sh [--commands DIR] [--skills DIR]
```

Defaults:
- `--commands`: `.specify/extensions/clickup/commands`
- `--skills`: `.claude/skills` (only `speckit-clickup-*/SKILL.md` are scanned)

| Rule | Fails when a scanned file… |
|---|---|
| G1 | contains `list_name`, `space_name` or `folder_name` |
| G2 | names a `clickup_*` tool outside the allowlist |
| G3 | reads a container name key as a locator: `config.workspace`, `config.space`, `config.folder`, `config.list` |
| G4 | names any `clickup_*` tool but never mentions `workspace_id` |

The G2 allowlist covers the ID-addressed tools only:
- `clickup_get_list`, `clickup_get_folder`, `clickup_create_list_in_folder`
- `clickup_create_task`, `clickup_update_task`, `clickup_get_task`
- `clickup_add_task_dependency`, `clickup_remove_task_dependency`
- `clickup_get_custom_fields`, `clickup_create_comment`

Output: one line per violation, `path:line: G<n> <message>`. Exit 0 when clean, 1 on any
violation, 2 on usage error.

Changing the allowlist is a deliberate edit to this script, reviewed like any other change.
