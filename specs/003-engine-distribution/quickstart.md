# Quickstart: validating Engine Distribution (003)

Ordered so everything before Scenario 4 runs fully offline. Prereqs: `specify` CLI ≥ 0.13
(`uv tool install specify-cli --from git+https://github.com/github/spec-kit.git` or a released
version), `gh` authenticated (Scenario 4+ only), `jq`, `zip`, a scratch directory.

## Scenario 1 — Release dry-run + offline catalog E2E (US1 + US2, no network)

1. `bash .specify/scripts/bash/release.sh 1.0.0 --dry-run` → builds `dist/` archives + a local
   catalog; expects: gate green, four ZIPs, zero forbidden-content hits, byte-stable on re-run.
2. Serve: `python3 -m http.server 8931` in the dist dir; rewrite `download_url`s to
   `http://localhost:8931/...` (the harness script does this).
3. Fresh consumer: `specify init t1 --integration claude`; register
   `catalog add http://localhost:8931/catalog.json --name snackbyte --install-allowed`;
   `specify extension add engine clickup git review-loop`.
4. **Expect**: all four install at the release version; `.claude/skills/` contains every engine +
   plug skill; installed `extensions.yml` hook entries match the manifests **field-for-field**
   (prompt, description, priority, optional) — the SC-004 fidelity diff; no
   `local-config.yml`/legacy local config anywhere in the install (SC-005 spot-check).

## Scenario 2 — Dependency guard (FR-008, offline)

In a fresh repo, install **only** `clickup` (CLI allows it — verified gap), then run
`/speckit-clickup-sync`. **Expect**: immediate, actionable failure naming
`specify extension add engine`; zero tracker writes.

## Scenario 3 — Update with consumer state (US3, offline)

1. In the Scenario-1 consumer: create `clickup-config.yml` (real-looking values) +
   `local-config.yml`; disable one hook in `extensions.yml`.
2. Re-run the harness at version+1; clear `.specify/extensions/.cache/`;
   `specify extension update` → confirm.
3. **Expect**: registry shows the new version for all four; both config files byte-identical
   (SC-003); the disabled hook still disabled; per-feature manifests untouched.

## Scenario 4 — Real release + Claude-repo install (US1 + US2, network)

1. `bash .specify/scripts/bash/release.sh 1.0.0` on `main` → tag `v1.0.0`, GitHub Release with
   four assets, committed `catalog.json`.
2. On a **different machine/checkout** (or clean clone): fresh Spec Kit repo, register the raw
   catalog URL (from [contracts/catalog.schema.md](contracts/catalog.schema.md)), install all
   four by name.
3. **Expect**: ≤ 3 consumer commands, < 5 min, no clone of this repo (SC-001); provision + sync
   against a real ClickUp space completes (SC-006 first half). Closes VALIDATION.md's
   "consolidated spine in a clean repo".

## Scenario 5 — Copilot-repo install (US4, network)

`specify init --integration copilot` + same catalog registration/install. **Expect**: all
commands render under `.github/prompts/` at parity with the Claude set; following the consumer
doc's ClickUp-connection section reaches a live provision + sync (SC-006 second half). Friend's
repo run = SC-007.

## Scenario 6 — Migration of a pre-release copy (FR-013)

On one of the three hand-copied repos (start with the lowest-stakes): follow the migration doc —
move real values `config.local.yml` → `local-config.yml`, delete the old extension dir(s) and
stale registry entry, catalog-install. **Expect**: existing `.clickup-sync.json` manifests
reconcile idempotently (0 duplicate cards, no re-provision); next sync is a no-op against an
unchanged repo.

## Sign-off map

| Scenario | Proves | Spec refs |
|---|---|---|
| 1 | build, leak scan, install-by-name, wiring fidelity | US1, US2, US5, SC-004, SC-005 |
| 2 | dependency guard | FR-008 |
| 3 | update preserves consumer state | US3, SC-003 |
| 4 | real publish + 3-command install | US1, US2, SC-001, SC-002, SC-006 |
| 5 | Copilot parity + docs-only onboarding | US4, SC-006, SC-007 |
| 6 | pre-release migration | FR-013 |
