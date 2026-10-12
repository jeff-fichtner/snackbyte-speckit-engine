# Contract: `clickup-config.yml` (ClickUp plug, repo-level, committed)

Location: `.specify/extensions/clickup/clickup-config.yml`. Layered below env
(`SPECKIT_CLICKUP_<KEY>`, `-`→`_`, uppercased) and `local-config.yml`, above the shipped
`extension.yml` defaults.

## Keys

| Key | Value | Required | Meaning |
|---|---|---|---|
| `workspace-id` | numeric ID | always | Workspace (ClickUp "team") every call is scoped to |
| `space-id` | numeric ID | always | Space the list belongs to (recorded in the manifest) |
| `list-id` | numeric ID | one of the two list targets | The shared list. Authoritative when set |
| `folder-id` | numeric ID | with `new-list-name` when `list-id` is absent | Where provision creates the list. Unused when `list-id` is set |
| `new-list-name` | text | with `folder-id` when `list-id` is absent | Name for the list provision creates. Replaced by `list-id` once pinned |
| `statuses` | block | no | Six logical states → status **names** on the list (the stated exception) |
| `enabled` | bool | no | `false` = repo declined ClickUp; every command is a silent no-op |
| `provenance-mode` | `A`\|`B` | no | Unchanged |

Container names belong in YAML comments. `workspace`, `space`, `folder` and `list` keys are
**name keys**:
- without their `-id` counterpart they are an **error**
- with it they are inert
- they are never read as locators

## Example (existing list)

```yaml
workspace-id: "90141363864"   # Workspace
space-id: "90146746995"       # products
list-id: "901421288946"       # karaoke / Roadmap
```

## Example (first feature of a new product)

```yaml
workspace-id: "90141363864"   # Workspace
space-id: "90146746995"       # products
folder-id: "901413565518"     # karaoke
new-list-name: "Roadmap"
```

After the first provision, `new-list-name: "Roadmap"` is rewritten to
`list-id: "<new id>"  # Roadmap`.

## Errors (provision stops before any ClickUp call; all errors are listed at once)

| Condition | Message (key first) |
|---|---|
| name key without its ID | `list: "Roadmap" is a name — containers are located by ID only; set list-id (keep the name as a comment)` |
| `workspace-id` / `space-id` missing | `workspace-id: required` |
| no `list-id` and no `folder-id` | `list-id: required — or set folder-id + new-list-name to create the list` |
| `folder-id` without `new-list-name` (no `list-id`) | `new-list-name: required with folder-id to create the list` |
| non-numeric `*-id` | `list-id: "Roadmap" is not a ClickUp ID (IDs are numeric)` |

## Where to find the IDs

- **Workspace and list**: open the list in ClickUp. Its URL is
  `https://app.clickup.com/<workspace-id>/v/l/li/<list-id>`.
- **Space and folder**: open the space or folder in ClickUp. Its ID appears in the URL.
