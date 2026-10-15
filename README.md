# snackbyte-speckit-engine

> **Deprecated (2026-10-14).** This engine is being replaced by its own engine in a new repo born
> from this one. It is based on and consumes Spec Kit pieces, plus
> [AI Hero](https://www.aihero.dev/) skills. This repo keeps working and stays up until every app
> has migrated off it. No further changes land here.
>
> Known gaps we would fix here, which the new engine's design accounts for:
>
> - **Nothing enforces review-loop, though it is a hard dependency.** `engine` installs without it,
>   and `/speckit-engine-verify` then fails at its first step. The new engine declares its hard
>   dependencies. If one is missing, it stops at the first step and names the missing piece and
>   how to install it.
> - **The ClickUp card hash ignores body content**
>   ([issue #1](https://github.com/jeff-fichtner/snackbyte-speckit-engine/issues/1)). Spec changes
>   that touch only prose never reach the card. The new engine's change detection covers
>   everything it mirrors.

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
the `git-lifecycle`, `review-loop`, and `agent-context` extensions. It is **not** a node package;
the `package.json` at the root exists only to provide the local check gate. Two commands, wired as
**required** lifecycle hooks in [`.specify/extensions.yml`](.specify/extensions.yml) (they run
automatically on every command; the plug's own config is where a repo opts out):

- **`/speckit-clickup-provision`** (`after_specify`): locate the pinned ClickUp list **by ID** (or
  create it in the pinned folder and pin its ID), resolve the status mapping, record targets in
  the feature manifest, and create the card in `open`. On an unconfigured repo it asks once for
  the IDs, saves what you give it, and remembers a decline (`enabled: false`) so it never
  re-asks.
- **`/speckit-clickup-sync`** (every lifecycle event: `after_specify` through `after_close`) —
  make the feature's ClickUp card (body, subtasks, checklist, dependencies, status) match the
  repo. One-way, idempotent (a no-op run makes zero ClickUp writes), MCP-only.

Configure the ClickUp plug in
[`.specify/extensions/clickup/clickup-config.yml`](.specify/extensions/clickup/clickup-config.yml)
(committed, consumer-owned — created by provision's ask-once flow on an unconfigured repo):

```yaml
# .specify/extensions/clickup/clickup-config.yml — IDs only; names belong in comments
workspace-id: "<workspace id>"   # e.g. Workspace
space-id: "<space id>"           # e.g. products
list-id: "<list id>"             # e.g. karaoke / Roadmap
```

Containers are located **by ID only**. A name is never a lookup, and a name key such as
`list: "Roadmap"` without its `list-id` is an error. A list's URL holds two of the IDs:
`app.clickup.com/<workspace-id>/v/l/li/<list-id>`. For a brand-new product with no list yet, set
`folder-id` + `new-list-name` instead of `list-id`. The first provision creates the list there and
pins its ID. Status mapping (`statuses:`) is by name: the one stated exception, because ClickUp
sets status by name.

No credentials go here; the connected ClickUp MCP server handles auth. Machine-local overrides go
in `local-config.yml` (gitignored). Both files survive `specify extension update`; everything else
in the extension is replaced on update. In *this* repo the config pins
`platforms / speckit-engine / Roadmap`.

## Install into your repo

The engine ships as **four versioned Spec Kit extensions** (`engine`, `clickup`,
`git-lifecycle`, `review-loop`) from this repo's catalog — no cloning, no file copying.
**If you are an agent setting up a consumer repo, these four commands are the whole job**
(skip any step whose result already exists):

```bash
# 0. spec-kit CLI ≥ 0.13, once per machine
uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
# 1. a Spec Kit project, once per repo (--integration copilot for GitHub Copilot)
specify init --here --integration claude
# 2. register this repo's catalog, once per repo
specify extension catalog add \
  https://raw.githubusercontent.com/jeff-fichtner/snackbyte-speckit-engine/main/catalog.json \
  --name snackbyte --install-allowed
# 3. install the engine suite (one extension per add)
for e in engine clickup git-lifecycle review-loop; do specify extension add "$e"; done
```

Exception: a repo holding a pre-v1.0.0 **hand-copied** install must follow
[docs/MIGRATION.md](docs/MIGRATION.md) instead (delete the old copies first).

Update any time with `specify extension update`. Full guide: [docs/CONSUMING.md](docs/CONSUMING.md) ·
maintainer runbook: [docs/RELEASING.md](docs/RELEASING.md) · pre-release repos:
[docs/MIGRATION.md](docs/MIGRATION.md).

## Check gate

```bash
npm run check:all      # shell-syntax lint + every *.test.sh (the ClickUp plug's helpers)
```

## Layout

```
.specify/extensions/clickup/              # the ClickUp plug (a Spec Kit extension)
├── extension.yml                         # package declaration + hook slots
├── clickup-config.yml                    # per-repo space/list (committed; no IDs/secrets)
└── commands/speckit.clickup.*.md         # the three command prompts (ClickUp MCP orchestration);
                                          #   deterministic helpers live in the engine extension
.claude/skills/speckit-clickup-*/         # user-invocable skill mirrors for the plug
.specify/extensions.yml                   # installs + wires plugs into the Spec Kit lifecycle
```

Only the extension payloads under `.specify/extensions/<name>/` are product.
Everything else here — Spec Kit itself, `specs/`, the release flow, the check
gate, agent config — is development apparatus for this repo and is never
exported to a consumer. See [`docs/EXPORT-BOUNDARY.md`](docs/EXPORT-BOUNDARY.md).

## Specs

- [`001-clickup-sync`](specs/001-clickup-sync/spec.md) — the ClickUp plug (shipped, validated
  end-to-end against a live ClickUp workspace). The first plug and the interface proof.
- [`002-clickup-lifecycle`](specs/002-clickup-lifecycle/spec.md) — the engine's fuller lifecycle:
  the post-implement test-everything + close-out gate, richer per-command status lifecycle,
  human-testing handoff, manual/light mode, commit/PR provenance, and agent-designed per-project
  rules. Most of it is engine (tracker-agnostic); ClickUp is one plug that reflects it. Specified
  and clarified; ready to plan.
