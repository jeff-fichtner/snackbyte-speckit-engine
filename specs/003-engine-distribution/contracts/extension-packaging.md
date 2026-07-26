# Contract: extension packaging — what ships, what never ships

Applies to all four extensions. The archive is the extension directory with `extension.yml` at
the archive root, named `{id}-{version}.zip`.

## Ships

- `extension.yml` — with this feature's additions:
  - `extension.version`: the lockstep release version
  - `requires.speckit_version: ">=0.13.0"` (honest floor; mechanism appeared in 0.13)
  - `requires.extensions` where real (clickup → engine) — informational to the CLI, enforced by
    the plug's runtime guard (see below)
  - `hooks.<event>` entries carrying the full canonical wiring metadata:
    `command`, `optional`, `priority`, `prompt`, `description`. The installer copies these
    verbatim into the consumer's `extensions.yml` (verified mechanism) — this IS FR-014.
  - clickup only: `config.defaults` with `<...>` placeholder values (replaces shipped
    `config.yml`)
- `commands/*.md` — command prompts (clickup's read config via the CLI naming/precedence and
  fail loud, naming `specify extension add engine`, when engine helpers are absent — FR-008)
- `scripts/bash/*.sh` + `*.test.sh` — deterministic helpers with their tests (tests ship;
  they're documentation and consumer-runnable verification)
- `README.md` — per-extension usage
- `.extensionignore` — present in the source dir to protect `--dev` installs; the CLI
  self-excludes it from install copies

## Never ships (excluded at zip time AND scanned post-build)

- `local-config.yml`, `clickup-config.yml`, legacy `config.yml` consumer values / `config.local.yml`
  — any file carrying a real workspace name
- caches (`.cache/`), backups (`.backup/`), OS junk (`.DS_Store`)
- anything matched by the repo `.gitignore` inside the extension dir

The post-build scan greps archive listings and contents for the forbidden names and this repo's
real workspace identifiers; a hit fails the release (SC-005's automated guarantee).

## Consumer-owned files (created in consumer repos, never packaged)

| File | Created by | Preserved on update because |
|---|---|---|
| `.specify/extensions/clickup/clickup-config.yml` | provision ask-once (or hand-created per docs) | matches the CLI rescue pattern `*-config.yml` (verified) |
| `.specify/extensions/clickup/local-config.yml` | consumer, gitignored | matches the rescue pattern (verified) |
| `specs/<feature>/.clickup-sync.json` | provision/sync | lives outside the extension dir entirely |

Legacy naming (`config.yml` / `config.local.yml`) is NOT rescued — verified clobber — which is
why the migration doc (FR-013) moves values to the new names before the first catalog install.
