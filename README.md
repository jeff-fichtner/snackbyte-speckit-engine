and # snackbyte-speckit-engine

**An engine for [Spec Kit](https://spec-kit.org).** If Spec Kit is a manual transmission — you
shift every gear yourself (`specify` → `clarify` → `plan` → `tasks` → `implement`) — this is the
engine that powers it: it senses where a feature is in its lifecycle, drives it forward, keeps the
lifecycle moving on its own, and mirrors that state out to the trackers you care about.

Entirely dependent on Spec Kit — it has no purpose without it.

## The idea: an engine with swappable plugs

The engine is **tracker-agnostic**. It owns the generic lifecycle work; a **plug** speaks a
specific tracker's language. The engine says "this feature reached review"; a plug turns that into
a real action in ClickUp, Linear, a local file, or wherever.

```
        ┌─────────────────────────── engine (generic) ───────────────────────────┐
        │  derive status · per-command lifecycle · close-out · handoff · manifest │
        └───────────────┬───────────────┬───────────────┬─────────────────────────┘
                        │               │               │
                   ┌────┴────┐     ┌────┴────┐     ┌────┴────┐
                   │  local  │     │ ClickUp │     │  …next  │   ← plugs (swappable)
                   │  plug   │     │  plug   │     │         │
                   └─────────┘     └─────────┘     └─────────┘
```

- **Zero plugs** — the engine still runs, recording lifecycle state via a built-in **local plug**
  (a file). Useful with no external tracker at all.
- **One plug** — attach ClickUp; the same lifecycle now also appears as ClickUp cards.
- **Many plugs** — attach several at once; the engine broadcasts each lifecycle event to all of
  them. Plugs are independent and don't know about each other.

Plugs are **purely additive**: attaching or removing one never changes what the engine does — it
only changes how many places the lifecycle is mirrored. The local plug is always in the box, which
is what makes "zero external plugs" still work.

## Status

- **The engine core** (a generic tracker interface + the local plug + the full lifecycle) is the
  target architecture — specified in [`002-clickup-lifecycle`](specs/002-clickup-lifecycle/spec.md)
  and not yet built as a separate layer.
- **The ClickUp plug** is real and shipped: it mirrors each Spec Kit feature into ClickUp as a
  feature-card + user-story subtasks + `tasks.md` checklist, derives status from the flow, one-way
  (repo is source of truth), idempotent, MCP-only. Specified and validated in
  [`001-clickup-sync`](specs/001-clickup-sync/spec.md). It is the first plug and the proof of the
  interface.

> Lineage: this repo began as `snackbyte-clickup-sync` — the ClickUp plug came first and proved
> out the model. The engine is being generalized from it. Git history reflects that progression.

## The ClickUp plug

Packaged as a standard Spec Kit extension under
[`.specify/extensions/clickup/`](.specify/extensions/clickup/) — the same shape as
the `git`, `review-loop`, and `agent-context` extensions. It is **not** a node package;
the `package.json` at the root exists only to provide the local check gate. Two commands, wired as
**required** lifecycle hooks in [`.specify/extensions.yml`](.specify/extensions.yml) (they run
automatically on every command; the plug's own config is where a repo opts out):

- **`/speckit-clickup-provision`** (`after_specify`) — find-or-create the ClickUp space + shared
  list, resolve the status mapping, record targets in the feature manifest, create the card in
  `open`. On an unconfigured repo it asks once for the space/list, saves what you give it, and
  remembers a decline (`enabled: false`) so it never re-asks.
- **`/speckit-clickup-sync`** (every lifecycle event: `after_specify` through `after_close`) —
  make the feature's ClickUp card (body, subtasks, checklist, dependencies, status) match the
  repo. One-way, idempotent (a no-op run makes zero ClickUp writes), MCP-only.

Configure the ClickUp plug in
[`.specify/extensions/clickup/config.yml`](.specify/extensions/clickup/config.yml):

```yaml
space: "<your-space-name>"        # ClickUp space the shared list lives in
list:  "<your-shared-list-name>"  # the one shared list all feature-cards go into
```

No IDs or credentials go here — the connected ClickUp MCP server handles auth, and runtime IDs
live only in each feature's `specs/<feature>/.clickup-sync.json` manifest. In *this* repo the
config points at the `snackbyte-speckit-engine` ClickUp space; a shippable copy ships the `<your-…>`
placeholders.

## Check gate

```bash
npm run check:all      # shell-syntax lint + every *.test.sh (the ClickUp plug's helpers)
```

## Layout

```
.specify/extensions/clickup/              # the ClickUp plug (a Spec Kit extension)
├── extension.yml                         # package declaration + hook slots
├── config.yml                            # per-repo space/list (no IDs/secrets)
└── commands/speckit.clickup.*.md         # the three command prompts (ClickUp MCP orchestration);
                                          #   deterministic helpers live in the engine extension
.claude/skills/speckit-clickup-*/         # user-invocable skill mirrors for the plug
.specify/extensions.yml                   # installs + wires plugs into the Spec Kit lifecycle
```

## Specs

- [`001-clickup-sync`](specs/001-clickup-sync/spec.md) — the ClickUp plug (shipped, validated
  end-to-end against a live ClickUp workspace). The first plug and the interface proof.
- [`002-clickup-lifecycle`](specs/002-clickup-lifecycle/spec.md) — the engine's fuller lifecycle:
  the post-implement test-everything + close-out gate, richer per-command status lifecycle,
  human-testing handoff, manual/light mode, commit/PR provenance, and agent-designed per-project
  rules. Most of it is engine (tracker-agnostic); ClickUp is one plug that reflects it. Specified
  and clarified; ready to plan.
