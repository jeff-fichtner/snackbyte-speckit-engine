# Releasing the engine (maintainer runbook — FR-006)

One release = one lockstep version across all four extensions, four ZIP assets on a GitHub
Release, and a regenerated committed `catalog.json`. Published releases are immutable — defects
roll forward to a new version, never a republish.

## The one action

```bash
bash .specify/scripts/bash/release.sh <version>       # e.g. 1.1.0 — from main, clean tree
```

That single command does everything, refusing loudly at the first problem:

1. **Preflight**: plain `MAJOR.MINOR.PATCH`, strictly greater than the last `v*` tag; tag free
   locally and on origin; clean tree; on `main`; `gh` (authenticated), `jq`, `zip`,
   `shasum` present.
2. **Stamp**: writes the version into all four `extension.yml` + `package.json` (SC-002's one
   bump action), then verifies zero drift.
3. **Gate**: full `npm run check:all` (includes `release.test.sh` + `wiring-fidelity.test.sh`).
4. **Build**: one deterministic ZIP per extension (fixed mtimes + sorted entries → re-running
   the same inputs is byte-identical). `.extensionignore` + built-in exclusions keep local
   config out.
5. **Scan**: forbidden file names (`config.local.yml`, `local-config.yml`,
   `clickup-config.yml`) and forbidden content (this repo's real ClickUp ids) inside any
   archive abort the release (SC-005).
6. **Catalog**: regenerates `catalog.json` (schema, lockstep versions, GitHub asset URLs,
   sha256 per archive).
7. **Publish**: commit `release: v<version>`, tag, push, `gh release create` with the four
   ZIPs. If a previous run died after the tag push, re-running completes the release
   idempotently; an existing GitHub release refuses.

## Rehearse first (no side effects)

```bash
bash .specify/scripts/bash/release.sh <version> --dry-run [--port 8931]
```

Stamps a temp copy (repo untouched), builds `dist/`, scans, and emits `dist/catalog.json`
(GitHub URLs) + `dist/catalog.local.json` (localhost URLs). Serve the repo root
(`python3 -m http.server 8931`) and point a scratch repo at
`http://localhost:8931/dist/catalog.local.json` for the full offline install/update E2E
(quickstart Scenarios 1–3).

## After publishing

- Consumers see the new version via `specify extension update` — up to **1 hour** later
  (catalog cache, no refresh flag). Announce accordingly.
- Never move `catalog.json` — its raw URL is the consumers' registered catalog.
- First release only: walk the three pre-release repos through
  [MIGRATION.md](MIGRATION.md).
