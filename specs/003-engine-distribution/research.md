# Research: Engine Distribution (003)

All findings below were verified live on 2026-07-24 against the installed CLI
(`specify 0.13.5.dev0`, upstream `github/spec-kit`) — by reading its extension-manager source and
by running a complete local end-to-end: ZIP builds for all four extensions → localhost catalog →
`catalog add` → install-by-name → version bump → `extension update`. Nothing here is assumed.

## Decision 1 — Distribution channel: GitHub Release assets + committed catalog.json

**Decision**: Publish each release as four ZIP assets (`{id}-{version}.zip`) on a GitHub Release
of this repo, plus a `catalog.json` committed at the repo root on `main`, registered by consumers
via its `raw.githubusercontent.com` URL.

**Rationale**: The CLI's catalog loader requires a stable HTTPS URL (localhost HTTP allowed for
testing only) and its downloader special-cases GitHub release asset URLs (resolves
`releases/download/...` to the API asset URL). The repo is public, so no consumer auth is needed.
A committed catalog gives history and atomic updates with the release commit.

**Alternatives considered**: GitHub Pages (extra moving part, no benefit at this scale); catalog
as a release asset itself (URL changes every release — breaks "register once"); npm (forbidden by
constitution's no-node-package constraint).

**Verified mechanics** (consumers): registration is
`specify extension catalog add <url> --name snackbyte --install-allowed` — the
`--install-allowed` flag is **required** (default is discovery-only; installs are refused without
it). Then `specify extension add engine` etc. resolves name → catalog → download → sha256 check →
install. Catalog resolution order: `SPECKIT_CATALOG_URL` env > project
`.specify/extension-catalogs.yml` > user `~/.specify/extension-catalogs.yml` > built-in defaults.

## Decision 2 — Catalog schema (as validated by the CLI)

```json
{
  "schema_version": "1.0",
  "extensions": {
    "<id>": {
      "name": "...", "description": "...", "version": "1.0.0",
      "download_url": "https://github.com/<owner>/<repo>/releases/download/v1.0.0/<id>-1.0.0.zip",
      "sha256": "<hex digest of the zip>"
    }
  }
}
```

The CLI hard-requires `schema_version` + `extensions` (JSON object). `sha256` is optional but
**verified when present** — we always include it. `download_url` must be HTTPS (or localhost
HTTP). Verified live: install-by-name with checksums passed; a tampered checksum fails the
install.

**Cache**: fetched catalogs are cached under `.specify/extensions/.cache/` for **3600 s** with no
CLI refresh flag. Consequence (verified live): right after a release, `extension update` can
report "Up to date" for up to an hour; deleting the cache dir forces a refetch. Consumer docs
must state this.

## Decision 3 — ZIP layout and leak prevention (two layers)

**Decision**: ZIP contains the extension directory contents with `extension.yml` at the archive
root (verified accepted; a single nested subdir also works). Exclusion of non-shippable files is
enforced twice: (a) each extension ships a `.extensionignore` (gitignore syntax, honored by the
CLI's install copy — covers `--dev` installs too, and the file always excludes itself), and
(b) the release script excludes the same set at zip time and scans the built archives for
forbidden content (fails loud on hit).

**Rationale**: Verified live that `--dev` install copies **everything**, including
`config.local.yml` with real workspace values — the leak the spec's FR-003 exists to prevent.
`.extensionignore` fixes the `--dev` path at the CLI layer; the release-script exclusion + scan
protects published artifacts even if an ignore file regresses.

## Decision 4 — Plug config must move to the CLI's protected naming (update-clobber fix)

**Decision**: The ClickUp plug's per-repo config migrates from `config.yml` + `config.local.yml`
(our pre-release naming) to the CLI convention: `clickup-config.yml` (committed, consumer-owned)
+ `local-config.yml` (gitignored, machine-local), read in the CLI's precedence order (env >
local > project > shipped defaults). The plug stops shipping a consumer-editable config file
entirely; provision's ask-once flow writes `clickup-config.yml`.

**Rationale — verified clobber**: `extension update` replaces every shipped file; its
config-rescue logic only recognizes names ending `-config.yml` / `-config.local.yml` (which
includes `local-config.yml`). Live test: a consumer-edited `config.yml` ("MY REAL SPACE") was
**silently reset to placeholders** by a 1.0.0→1.0.1 update. Under the CLI naming the same file
survives. This also gives env-var overrides (`SPECKIT_CLICKUP_*`) for free.

**Alternatives considered**: keep `config.yml` and document "re-fill after update" (violates
FR-012); ship no default and rely on docs only (loses the ask-once UX).

**Note on hand-edited *shipped* files** (FR-012 second clause): the CLI replaces shipped files
without diffing. Mitigation within our control: docs draw a hard shipped-vs-owned line, and
consumers' git makes any overwrite visible/revertable — plus the update flow itself prints what
it replaces. Recorded as a known substrate limitation; candidate upstream issue, not a blocker.

## Decision 5 — Hook fidelity is pure extension.yml metadata

**Decision**: Add `prompt`, `priority`, `description` (and explicit `optional`) to every hook
entry in each extension's `extension.yml`, mirroring the curated wiring in this repo's
`extensions.yml`. The canonical-wiring reconciliation originally listed here was completed in-repo
(2026-07-25/26): the stale ids were fixed, and the `specify-review-loop` + `analyze-autofix`
pair was merged into the single `review-loop` extension (targets `spec | analysis | code`)
under Constitution VII — the release ships four extensions, not five.

**Rationale**: The installer builds consumer `extensions.yml` entries via
`entry.get("prompt", f"Execute {command}?")`, `entry.get("priority", 10)`, etc. — the generic
prompts in fresh installs exist only because our manifests never set the fields. No CLI change
needed; FR-014's mechanism already exists.

## Decision 6 — Dependency (clickup → engine) is NOT enforced by the CLI

**Verified live**: `specify extension add clickup` in a repo with no engine installed succeeds —
`requires.extensions` is displayed by `extension info` but never enforced. **Decision**: satisfy
FR-008 with (a) a fail-loud runtime guard in the plug's commands (they already call
`.specify/extensions/engine/scripts/bash/*`; make the missing-engine case a clear, actionable
error naming `specify extension add engine`), and (b) install-order documentation. No installer
wrapper script — it would duplicate the CLI and rot.

## Decision 7 — Release script: one bash entrypoint, maintainer-local, gh-driven

**Decision**: `.specify/scripts/bash/release.sh <version>` — the single release action (per
Clarifications 2026-07-24). Behavior: preflight (clean tree, on main, `gh`/`jq`/`zip` present —
fail loud, no fallbacks), stamp `<version>` into all four `extension.yml` + root `package.json`
(lockstep, satisfies SC-002's one-action bump), run the full check gate, build the four ZIPs with
exclusions, sha256 them, regenerate `catalog.json`, forbidden-content scan, commit + tag
`v<version>`, `gh release create` with the four assets. Refuses to republish an existing tag.
Deterministic helpers (version stamping/consistency, file selection, catalog generation, archive
scan) live in tested functions with `release.test.sh` in the existing gate; the publish step
(gh/network) stays thin and untested-by-unit, per Constitution V's tested/orchestration split.

**Alternatives considered**: CI on tag (rejected by user decision — may reuse this script
later); `git archive`-based packaging (fights the exclusion list less flexibly than zip + ignore
patterns).

## Decision 8 — Version floor honesty

**Decision**: bump every extension's `requires.speckit_version` from the stale `">=0.2.0"` to
`">=0.13.0"` (first version with the extension mechanism). Implementation verifies against the
current released CLI (0.14.x) in quickstart; the floor claim stays 0.13.

## Decision 9 — Migration path for pre-release copies (3 repos)

**Decision**: documented manual migration (audience is 3 repos, all maintainer-owned): delete the
old hand-copied `clickup-sync`/`clickup` extension dir + stale registry entry, install from the
catalog, move real config values into `local-config.yml`/`clickup-config.yml`. Per-feature
`.clickup-sync.json` manifests stay untouched — sync is manifest-driven and idempotent, so
existing cards reconcile without duplicates (verified property from 001/002). The version rewind
(pre-release "2.0.0" > official 1.0.0) is inert after reinstall because the registry entry is
recreated at 1.0.0; `update`'s strictly-greater comparison then works normally.

## Decision 10 — Local E2E harness is reproducible and becomes the test backbone

The localhost flow used for this research (build ZIPs → generate catalog with real sha256s →
`python3 -m http.server` → `catalog add http://localhost:<port>/catalog.json` → install/update)
is scripted into the quickstart and reused as the release script's integration self-test. This
keeps SC-001/SC-003 verifiable offline before any real GitHub release exists.
