# Data Model: Engine Distribution (003)

File-based throughout; no databases. Consumer-side entities marked **(CLI-owned)** are written by
the upstream specify CLI — we conform to them, never modify their code.

## Release

One published version of the whole suite (lockstep — user decision 2026-07-24).

| Field | Source | Rules |
|---|---|---|
| `version` | argument to `release.sh` | semver `MAJOR.MINOR.PATCH`; strictly greater than the last published tag; stamped identically into all four `extension.yml` + root `package.json` |
| `tag` | git | `v<version>`; existing tag ⇒ release refuses (immutability) |
| `assets` | build output | exactly four archives, `{id}-{version}.zip` |
| `catalog state` | generated | `catalog.json` regenerated in the same commit as the stamp |

**Transitions**: `working` → (stamp + gate green + scan clean) → `published` (immutable) →
`superseded` (by any higher version). No in-place mutation of a published release; defects roll
forward.

## ExtensionArchive

| Field | Rules |
|---|---|
| `id` | one of `engine`, `clickup`, `git`, `review-loop`; must equal the command namespace (`speckit.<id>.*`) — CLI-enforced at install |
| `contents` | extension dir with `extension.yml` at archive root |
| `excluded` | `.extensionignore` patterns ∪ gitignored files: local config (`local-config.yml`, legacy `config.local.yml`), caches, backups. Enforced at zip time AND scanned post-build (any hit fails the release) |
| `sha256` | computed at build; embedded in the catalog entry; CLI verifies on download |

## Catalog

`catalog.json` at repo root on `main`; consumers register its raw HTTPS URL once.

| Field | Rules |
|---|---|
| `schema_version` | `"1.0"` (CLI requires presence) |
| `extensions` | JSON object keyed by extension id (CLI requires object shape) |
| `extensions.<id>.version` | equals the Release version for every id (lockstep invariant — generation fails on drift) |
| `extensions.<id>.download_url` | HTTPS GitHub release-asset URL for `{id}-{version}.zip` |
| `extensions.<id>.sha256` | required by us (optional to the CLI, verified when present) |
| `extensions.<id>.name/description` | from the extension manifest |

**Invariant**: the catalog's path/URL never changes ("register once"); its content only changes
by release commits. Consumer visibility of a new version lags up to 3600 s (CLI cache, no
refresh flag) — documented, not fought.

## ExtensionManifest (per extension, shipped)

Existing entity; fields this feature adds or corrects:

| Field | Change |
|---|---|
| `extension.version` | participates in lockstep stamping |
| `requires.speckit_version` | `">=0.2.0"` → `">=0.13.0"` (honest floor) |
| `requires.extensions` | kept (documentation value) — NOT CLI-enforced; runtime guard compensates |
| `hooks.<event>.prompt` / `.priority` / `.description` / `.optional` | NEW — canonical wiring metadata; installer copies them verbatim into consumer `extensions.yml` (verified mechanism) |
| `config.defaults` | NEW (clickup) — shipped placeholder defaults replacing the shipped `config.yml` |

## ConsumerPlugConfig (clickup)

The consumer-owned state FR-012 protects, in CLI naming (research Decision 4):

| File | Owner | Update behavior (verified) |
|---|---|---|
| `.specify/extensions/clickup/clickup-config.yml` | consumer (committed) | preserved by CLI rescue (`*-config.yml`) |
| `.specify/extensions/clickup/local-config.yml` | consumer (gitignored, machine-local) | preserved by CLI rescue |
| legacy `config.yml` / `config.local.yml` | pre-release installs only | clobbered/orphaned on update — migration path required (FR-013) |

Read precedence in plug commands: env (`SPECKIT_CLICKUP_*`) > `local-config.yml` >
`clickup-config.yml` > `config.defaults` (placeholders ⇒ ask-once/refuse guard unchanged).

## InstallRegistryRecord (CLI-owned)

`.specify/extensions/.registry` per extension: `version`, `source`, `manifest_hash`,
`enabled`, `priority`, `registered_commands.<integration>`, `installed_at`. Relevant behaviors:
update requires catalog `version >` registry `version` (strictly greater — rewind is inert
after reinstall); records are recreated on install (migration relies on this).

## CanonicalWiring

The curated hook set consumers must receive (US5/FR-014). Source of truth: each extension's
`extension.yml` hooks (with the new metadata) — NOT this repo's `extensions.yml` (the pre-rename
drift it once carried was reconciled 2026-07-25/26, including the merge of the review pair into
`review-loop`). Fidelity test: field-for-field equality (event, extension
id, command, enabled, optional, priority, prompt, description) between a fresh install's
`extensions.yml` and the manifests.
