# Contract: `catalog.json` — the consumer registration point

Hosted at the repo root on `main`; consumers register the raw URL exactly once:

```
specify extension catalog add \
  https://raw.githubusercontent.com/jeff-fichtner/snackbyte-speckit-engine/main/catalog.json \
  --name snackbyte --install-allowed
```

`--install-allowed` is mandatory for installs (CLI default is discovery-only — verified).
The URL is a stability contract: the file may change content on releases, never location.

## Schema (validated shape, verified against CLI 0.13.5)

```json
{
  "schema_version": "1.0",
  "extensions": {
    "engine":              { "name": "...", "description": "...", "version": "<release>",
                             "download_url": "https://github.com/.../v<release>/engine-<release>.zip",
                             "sha256": "<hex>" },
    "clickup":             { "...": "same shape" },
    "git-lifecycle":       { "...": "same shape" },
    "review-loop":         { "...": "same shape" }
  }
}
```

Rules:
- `schema_version` and `extensions` (object) are CLI-required; absence ⇒ "Invalid catalog format".
- All four `version` values are identical (lockstep) — generation enforces it.
- `download_url`: HTTPS only (CLI-rejected otherwise; localhost HTTP allowed only in the offline
  test harness). GitHub `releases/download/...` URLs are auto-resolved by the CLI through the
  GitHub API.
- `sha256`: always emitted; the CLI verifies it on download when present.

## Consumer semantics (verified behaviors to document)

- **Install**: `for e in engine clickup git-lifecycle review-loop; do specify extension add "$e"; done`
  (or per-extension). Name resolution goes through the merged catalog stack; project-level
  registration wins over user-level and built-ins.
- **Update**: `specify extension update` compares catalog version **strictly greater** than the
  registry version, confirms interactively, downloads + verifies + swaps atomically
  (backup/restore on failure).
- **Cache**: catalog fetches cache for 3600 s under `.specify/extensions/.cache/`; there is no
  refresh flag. A just-published release may not be visible for up to an hour; deleting the
  cache directory forces a refetch. Docs state both.
- **Uninstall**: `specify extension remove <id>` (CLI-provided; documented in the consumer
  guide with the config-preservation note).
