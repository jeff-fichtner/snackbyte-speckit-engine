# Consuming the engine (install · configure · update · uninstall)

Everything a repo needs to run the snackbyte-speckit-engine — four Spec Kit extensions
(`engine`, `clickup`, `git-lifecycle`, `review-loop`), installed by name from one catalog.
No cloning, no file copying.

## Prerequisites

- The **spec-kit CLI ≥ 0.13** (`specify`). Install a released version:
  ```bash
  uv tool install specify-cli --from git+https://github.com/github/spec-kit.git
  ```
- A Spec Kit project: `specify init <dir> --integration claude` (Claude Code) or
  `--integration copilot` (GitHub Copilot). Both are supported; other integrations are untested.
- For the ClickUp plug: a connected **ClickUp MCP server** (see the Copilot section below;
  Claude Code users connect the ClickUp connector/MCP in their client).

## Install

```bash
specify extension catalog add \
  https://raw.githubusercontent.com/jeff-fichtner/snackbyte-speckit-engine/main/catalog.json \
  --name snackbyte --install-allowed
specify extension add engine clickup git-lifecycle review-loop
```

Notes that save you a support round-trip:

- **`--install-allowed` is required** — without it the catalog is discovery-only and installs
  are refused.
- Install the four together (one command above). The ClickUp plug **requires `engine`** and
  fails loud without it — the CLI does not enforce the dependency itself.
- Do **not** name your own extension `git` — spec-kit bundles a `git` extension and
  `extension add git` always resolves to the bundled one (why ours is `git-lifecycle`).
- Archives are sha256-verified against the catalog automatically.

## Configure the ClickUp plug

Config is layered, highest wins: env (`SPECKIT_CLICKUP_<KEY>`) → `local-config.yml`
(gitignored, machine-local) → `clickup-config.yml` (committed, repo-level) → shipped defaults.

You normally configure nothing by hand: the first lifecycle command asks once for your space +
list and writes `clickup-config.yml`; declining writes `enabled: false` there and never asks
again. To pre-seed or retarget:

```yaml
# .specify/extensions/clickup/clickup-config.yml   (names only — no IDs, no secrets)
space: "My Space"
list: "My List"
```

Runtime ClickUp IDs live only in each feature's `specs/<feature>/.clickup-sync.json`.

## Update

```bash
specify extension update
```

- Compares your installed versions against the catalog and confirms before changing anything.
- **Preserved**: `clickup-config.yml`, `local-config.yml`, every `specs/*/.clickup-sync.json`.
- **Replaced**: everything else the extensions ship (command bodies, scripts, manifests).
  Never hand-edit shipped files — your edit is overwritten on the next update (visible in git,
  but not merged).
- **Known limitation**: hook `enabled:` toggles in `.specify/extensions.yml` are regenerated on
  update — re-apply them, or use the durable opt-out (`enabled: false` in `clickup-config.yml`).
- **Catalog cache**: catalog fetches are cached for **1 hour** with no refresh flag. A release
  published minutes ago may not be visible yet; delete `.specify/extensions/.cache/` to force a
  refetch.

## Uninstall

```bash
specify extension remove clickup   # etc.
```

Per-feature manifests and your config files are yours; remove them only if you want them gone.
Removing `engine` while `clickup` is installed leaves the plug failing loud by design.

## GitHub Copilot: connecting the ClickUp MCP server (T016 / FR-015)

The plug is MCP-only — it needs a ClickUp MCP server visible to your agent:

1. In VS Code, add the ClickUp MCP server to your workspace or user MCP config
   (`.vscode/mcp.json`, or the Copilot Chat MCP settings UI), e.g. the official/hosted ClickUp
   MCP endpoint or a local server, and authenticate it with **your** ClickUp workspace when
   prompted.
2. Verify Copilot Chat lists the `clickup_*` tools (workspace hierarchy, tasks, comments).
3. Run your first lifecycle command (e.g. `/speckit.specify`): the plug asks once for your
   space + shared list, provisions the card, and syncs from then on. All auth lives in the MCP
   server — the extensions never see credentials.

If the tools are missing, every sync no-ops with a clear message rather than failing your
lifecycle commands.

## Pre-release (hand-copied) installs

See [MIGRATION.md](MIGRATION.md).
