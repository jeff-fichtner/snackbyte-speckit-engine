# Contract: `release.sh` — the one release action

`bash .specify/scripts/bash/release.sh <version> [--dry-run]`

Maintainer-local (user decision 2026-07-24). One argument, one outcome: either a fully published
release `v<version>` with five assets and an updated committed catalog, or a loud failure with
nothing published.

## Preflight (all fail-loud, in order; nothing mutated before all pass)

1. `<version>` is semver and strictly greater than the latest existing `v*` tag.
2. Working tree clean, current branch `main`, `origin` reachable.
3. Required tools present: `gh` (authenticated), `jq`, `zip`, `shasum` or `sha256sum` — missing
   tool names the binary and stops (no fallbacks, per house config rules).
4. Tag `v<version>` does not already exist locally or on origin (immutability).

## Steps

1. **Stamp** `<version>` into all four `extensions/*/extension.yml` + root `package.json`
   (SC-002's single bump action), then verify zero version drift across the five files.
2. **Gate**: run the full check gate (`npm run check:all`, which includes `release.test.sh`).
   Red gate ⇒ abort before any artifact exists (FR-005).
3. **Build**: per extension, zip the directory honoring `.extensionignore` + the exclusion list
   (legacy + CLI-convention local config names, caches, backups); `extension.yml` at archive
   root; deterministic file ordering (repeatable builds — US1 scenario 4).
4. **Scan**: unzip-list + content-scan every archive for forbidden files/values (local config
   names, real workspace identifiers); any hit ⇒ abort (FR-003 / SC-005).
5. **Catalog**: regenerate `catalog.json` from the manifests + built archives (names,
   descriptions, `<version>`, GitHub release-asset `download_url`s, sha256 digests).
6. **Publish**: commit stamp + catalog (`release: v<version>`), tag `v<version>`, push, then
   `gh release create v<version>` attaching the four ZIPs. `--dry-run` stops before this step,
   leaving the tree clean (stamp/catalog changes reverted or never written — dry-run is
   side-effect-free).

## Failure modes

| Failure | Behavior |
|---|---|
| any preflight miss | named error, exit ≠ 0, no changes |
| gate red | abort; stamp not committed |
| drift between stamped versions | named file list, abort |
| forbidden content in an archive | named archive + pattern, abort, nothing published |
| tag/release already exists | abort (roll forward with a new version instead) |
| `gh release create` fails mid-publish | tag exists but release incomplete ⇒ re-run is safe: the script detects the pushed tag with missing release/assets and completes idempotently |

## Tested vs. orchestrated (Constitution V)

Unit-tested deterministic functions (in `release.test.sh`, wired into the gate): version
validation/stamping/drift check, exclusion/file-selection, catalog generation (given fixed
inputs → byte-stable output), forbidden-content scan. Quickstart-validated orchestration: git
operations, `gh` publish, network.
