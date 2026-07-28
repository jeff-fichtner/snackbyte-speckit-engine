# Migrating a pre-release install to the catalog (FR-013)

Applies to repos that received the engine (or the old `clickup-sync` plug) by **hand-copying**
before v1.0.0 — known instances: `bed-generators`, `snackbyte-discord`, `snackbyte-links`.
Do this **after** v1.0.0 is published (the catalog URL below must resolve).

Your per-feature manifests (`specs/<feature>/.clickup-sync.json`) are untouched by every step —
they live outside the extension dirs, and the sync is manifest-driven and idempotent, so your
existing ClickUp cards reconcile without duplicates when you sync again.

## Steps

1. **Save your real config values.** Pre-release naming kept them in
   `.specify/extensions/<plug>/config.local.yml` (or filled-in `config.yml`). Note the `space`,
   `list`, and any `statuses:` block.
2. **Delete the hand-copied extension dirs** — any of: `clickup-sync/`, `clickup/`, `engine/`,
   `git/`, `git-specify-branch/`, `git-commit/`, `specify-review-loop/`, `analyze-autofix/`
   under `.specify/extensions/`. Also delete `.specify/extensions/.registry` entries for those
   ids if the file exists (or the whole `.registry` if it only contains them).
   The pre-release `clickup` version "2.0.0" being higher than the official 1.0.0 does not
   matter: reinstalling recreates the registry entry at 1.0.0, and future updates compare
   against that (research D9 — the rewind is inert).
3. **Install from the catalog** (spec-kit CLI ≥ 0.13 required):
   ```bash
   specify extension catalog add \
     https://raw.githubusercontent.com/jeff-fichtner/snackbyte-speckit-engine/main/catalog.json \
     --name snackbyte --install-allowed
   specify extension add engine clickup git-lifecycle review-loop
   ```
4. **Restore your config under the new names** (preserved across future updates):
   - `.specify/extensions/clickup/clickup-config.yml` (committed) — `space`, `list`,
     optional `statuses:` block
   - `.specify/extensions/clickup/local-config.yml` (gitignored) — machine-local overrides only
   Do NOT recreate `config.yml`/`config.local.yml`; those names are replaced/orphaned by
   updates.
5. **Reconcile**: run your next lifecycle command (or `/speckit-clickup-sync` directly). Expect:
   existing cards update in place — **zero new duplicate cards** (the manifest is the dedup
   index). A second sync with no repo changes is a **no-op** (zero ClickUp writes).

## Verify (per repo)

- `specify extension list` shows the four extensions at the same release version.
- `specs/*/.clickup-sync.json` byte-identical to before the migration.
- ClickUp list shows the same cards as before — no duplicates.

## Known limitation

Hook `enabled:` toggles in `.specify/extensions.yml` are regenerated on `specify extension
update` (CLI behavior) — re-apply any disables after updating, or use the durable opt-out:
`enabled: false` in `clickup-config.yml` (survives updates, silences all ClickUp syncs).
