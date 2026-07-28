# The engine (`.specify/` layout)

This directory holds **snackbyte-speckit-engine** — a Spec Kit lifecycle engine — plus its tracker
**plugs**. See the [root README](../README.md) for the concept; this file maps the concept onto the
files.

## Engine vs. plugs

- **Engine (generic, tracker-agnostic)** — derives a feature's lifecycle state from repo artifacts,
  advances it through grouped phases as Spec Kit commands run, drives the close-out ceremony and
  handoff, and broadcasts each lifecycle event to whatever plugs are attached. The engine never
  talks to a tracker directly (Constitution II). Its full lifecycle is specified in
  [`specs/002-clickup-lifecycle`](../specs/002-clickup-lifecycle/spec.md); the generic core is not
  yet extracted into its own layer — today it lives inside the first plug and is being generalized
  out of it.
- **Plug (swappable tracker adapter)** — one implementation of the tracker interface (resolve-target
  / create-update-item / set-checklist / link-dependency / update-status / attach-provenance). The
  engine runs with **zero** external plugs (a built-in local plug records state to a file), **one**,
  or **many** at once; plugs are independent and purely additive (Constitution VI).

## What's here

```
.specify/
├── extensions.yml                     # installs + wires the engine's modules + plugs
├── extensions/                        # the engine spine — snackbyte's lifecycle modules (US9)
│   ├── engine/                        # lifecycle core: derive/manifest/parse/status-map/provenance,
│   │                                  #   verify + close ceremonies, and the auto-chain hooks
│   ├── git-lifecycle/                 # branch prep (before_specify) + spec checkpoint (before_implement)
│   ├── review-loop/                   # the review stage (Constitution VII) — targets: spec | analysis | code
│   └── clickup/                       # the ClickUp plug (first external plug) — see its README
├── memory/
│   └── constitution.md                # the engine's constitution (governs engine + every plug)
├── scripts/bash/                      # shared repo-side helpers + the check-gate test runner
├── templates/                         # Spec Kit spec/plan/tasks/checklist/constitution templates
└── workflows/                         # Spec Kit workflow definitions
```

**Consolidation (US9):** the four extensions above are snackbyte's own lifecycle modules, brought
into this one engine repo and wired through the single `extensions.yml` (research Decision 1: one
repo + one registry, not a merged monolith). The upstream **`agent-context`** extension (authored by
`spec-kit-core`, not snackbyte) is deliberately **excluded** — it is not copied, absorbed, or
modified here; the engine coexists with it as a separate community extension you may install
alongside (FR-038).

## Where each concern lives today

| Concern | Engine or plug | Location today |
|---|---|---|
| Lifecycle status derivation | engine logic | `extensions/engine/scripts/bash/derive-status.sh` (to be generalized) |
| Manifest / idempotence index | engine logic | `extensions/engine/scripts/bash/manifest.sh` (to be generalized) |
| `tasks.md` parsing | engine logic | `extensions/engine/scripts/bash/parse-tasks.sh` (to be generalized) |
| ClickUp I/O (MCP orchestration) | ClickUp plug | `extensions/clickup/commands/*.md` |
| Local plug (zero-tracker default) | engine (built-in plug) | not yet built — target of `002` |
| Close-out / handoff ceremony | engine | not yet built — specified in `002` (US1/US2) |

The deterministic helpers currently sit inside the ClickUp plug for historical reasons (the plug
came first). Generalizing them into an engine core with a tracker interface — and adding the local
plug and the close-out/handoff ceremony — is the work `002-clickup-lifecycle` specifies.
