# ClickUp plug (Spec Kit extension)

The **ClickUp plug** for [snackbyte-speckit-engine](../../../README.md) — the first (and, so far,
only) external tracker plug. It is one implementation of the engine's tracker interface: the engine
drives the generic lifecycle, this plug turns those lifecycle events into real ClickUp actions.

**The tracker interface a plug implements** (what the engine asks any plug to do):

- **resolve-target / status-mapping**: locate the tracker's container and map the engine's
  **six logical states** (`open · in-design · ready · in-development · in-review · done`) onto the
  tracker's real statuses. Here: locate the pinned ClickUp list **by ID** (or create it in the
  pinned folder and pin it), then map the six onto the list's statuses, falling back to three
  where a list can't express six.
- **create/update item** — materialize a feature and its user stories as tracker items.
- **set-checklist** — render the feature's `tasks.md` lines onto the item.
- **link-dependency** — reflect user-story dependencies.
- **update-status** — write the derived lifecycle state (card: six states; subtasks: three).
- **attach-provenance** — link the commits that shipped the feature (Option A, hash-deduped).

Another plug (Linear, a local file, …) implements the same interface its own way; the engine does
not change. This plug's implementation follows.

> **Seam, not machinery (research Decision 7).** The interface above is the boundary that lets a
> second plug slot in. The engine's **local plug** (zero-tracker file mode) and **multi-plug
> broadcasting** are specified (FR-032/SC-013) but deliberately **not built** — ClickUp is the one
> concrete plug today. An uninstalled/disabled plug is a silent no-op, not an error
> (Constitution VI), so adding a plug later is additive, never a rework.

---

Mirrors each Spec Kit feature into ClickUp for project-management visibility. **One-way**
(repo → ClickUp), idempotent, and **MCP-only** — every ClickUp operation goes through the
connected ClickUp MCP server; this plug ships no API client, auth, or credentials.

## What it creates in ClickUp

```
Shared List (one per repo)
└── Feature-card (one ClickUp task per feature)        ← verbose body + derived status
    ├── US-subtask (one per user story)                ← native dependency links
    │     description: "- [ ] T001 …" checkbox list    ← one line per tasks.md task
    └── …
```

- **Feature → ClickUp task** ("feature-card") in a single shared list.
- **User story → subtask** under the card, carrying native ClickUp dependency links
  (US3 waits-on US1 & US2), derived from the spec's user-story numbering.
- **`tasks.md` line → markdown checkbox** inside its US-subtask's description. (The ClickUp
  MCP server has no checklist API, so the checklist is rendered as markdown in the task
  description.)
- **Status** (`not-started` / `in-progress` / `done`) derived from the feature's Spec Kit
  stage (plan presence + checkbox counts) and written via a per-list status mapping.
- The card **materializes as soon as `spec.md` exists** and is enriched on every later sync.

## Configure

Config is layered, highest wins: env (`SPECKIT_CLICKUP_<KEY>`) → `local-config.yml`
(gitignored, machine-local) → [`clickup-config.yml`](clickup-config.yml) (committed,
consumer-owned) → shipped defaults in `extension.yml`. Both consumer files survive `specify
extension update` (CLI config-rescue naming); everything else is replaced on update.

Containers are located **by ID only**. Names are comments, never lookups. Provision's ask-once
flow writes this for you on an unconfigured repo:

```yaml
# .specify/extensions/clickup/clickup-config.yml — IDs only; names belong in comments
workspace-id: "<workspace id>"   # e.g. Workspace
space-id: "<space id>"           # e.g. products
list-id: "<list id>"             # e.g. karaoke / Roadmap
```

| Key | Required | Meaning |
|---|---|---|
| `workspace-id` | always | Workspace every ClickUp call is scoped to |
| `space-id` | always | Space the list belongs to |
| `list-id` | or `folder-id` + `new-list-name` | The shared list; authoritative |
| `folder-id` + `new-list-name` | when there is no list yet | Provision creates the list in the folder, then rewrites `new-list-name` to the pinned `list-id` |
| `statuses:` | no | Six logical states → status **names** on the list: the one stated exception, because ClickUp sets status by name |

A list's URL holds two of the IDs: `app.clickup.com/<workspace-id>/v/l/li/<list-id>`. A missing
required ID, a name key without its ID (`list: "Roadmap"`), or a non-numeric ID stops provision
before any ClickUp call, naming the key. Resolution lives in
[`scripts/bash/targets.sh`](scripts/bash/targets.sh) (unit-tested). Moving from a name-based
config: [docs/MIGRATION.md](../../../docs/MIGRATION.md).

## Commands & hooks

| Command | Hook | What it does |
|---|---|---|
| `/speckit-clickup-provision` | `after_specify` (required) | Locate the pinned list by ID (or create it in the pinned folder and pin it), resolve & record the status mapping and target IDs into the feature manifest; card created in `open`. |
| `/speckit-clickup-sync` | every lifecycle moment, required — `after_specify`, `after_tasks`, `after_analyze` (sets `analyzed` → `ready`), `before_implement` (sets `implementStarted` → `in-development`), `after_converge`, `before_verify`, `after_verify` (→ `in-review`), `after_close` (→ `done`) | Make the feature-card (body, US-subtasks, checklist, dependencies, status) match the repo. Idempotent — a no-op run makes zero ClickUp writes. Opt out per repo via `enabled: false` in config. |

## State

Each feature carries a committed manifest at `specs/<feature>/.clickup-sync.json` holding the
target IDs, the status mapping, the card + US-subtask IDs, and content hashes. It is the
dedup index (create/update/skip) and the per-feature target locator. Committed ClickUp IDs live
in exactly two places: the consumer's `clickup-config.yml` (target containers) and these
manifests (created items). Nothing in this package contains IDs or secrets.

## Guarantees

- **One-way**: the sync overwrites ClickUp toward the repo; it never writes back to
  `tasks.md` or any repo artifact, and a hand-edit in ClickUp is reverted on the next sync.
- **MCP-only**: no custom ClickUp API/auth code.
- **Portable**: set only `clickup-config.yml` to retarget a different workspace/space/list — no
  code edits.
- **Scaffolding-only**: this lives entirely under `.specify/` + `.claude/` + per-feature
  manifests; it introduces no ClickUp references into shipped app source, docs, or CI.

## Repo-side helpers

Deterministic logic is unit-tested (`*.test.sh`). Config resolution and the list pin live in this
plug's [`scripts/bash/targets.sh`](scripts/bash/targets.sh). Tasks.md parsing, status derivation,
manifest I/O and hashing live in the engine's `scripts/bash/`. The command prompts own
only the ClickUp MCP orchestration, which is validated manually via the feature's
`quickstart.md` against a real workspace.
