# Backlog: Provision resolves the shared list by name across a whole space — ambiguous when two repos share a space

**Status**: Backlog (not yet specified — do NOT run `/speckit-specify` here yet).
**Found live 2026-08-29** in the MCDS space, where two consumer repos now both target a
list named `Roadmap`. Worked around in the consumers by convention, not by code: see
"Current mitigation" below.

## The problem, plainly

[`speckit.clickup.provision.md`](../../../.specify/extensions/clickup/commands/speckit.clickup.provision.md)
step 4 finds the shared list **by name, across the entire space**:

> If a list named `config.list` already exists under the space (from the hierarchy), adopt
> its id (no create — this is the reuse path for the 2nd+ feature).

Two things are wrong with that once a space holds more than one project:

1. **No folder scoping.** A space commonly holds one folder per project, each with its own
   lists. Two projects that both call their delivery list `Roadmap` — a perfectly natural
   convention, and the one that emerged on its own across two repos — are indistinguishable
   to this lookup.
2. **No ambiguity guard.** Step 3 stops and asks when a *space* name matches more than once
   (">1 matches (ambiguous): stop and ask the user to disambiguate; do not guess"). Step 4
   has no equivalent for lists, so a duplicate name silently resolves to whichever the
   hierarchy yields first.

The failure is quiet and cross-project: provision records the wrong `listId` into
`specs/<feature>/.clickup-sync.json`, and every subsequent sync for that feature dutifully
writes cards into **another repo's list**. Nothing errors. The manifest is the target
locator, so the mistake is durable and only visible by noticing foreign cards on a board.

Blast radius is limited by *when* it can happen: provision runs only at `after_specify`.
Sync, verify, and close all address the list by the manifest's `listId`, never by name — so
an already-provisioned feature is unaffected. The bug can only bite a **new spec**.

## The sketched fix

Add an optional `folder:` key to the plug's config (layered like `space`/`list`), and in
provision step 4:

- When `folder` is set, resolve the folder within the space first, then look for `list`
  **only among that folder's lists**. Stop with a clear message if the folder does not exist
  — do not fall back to a space-wide search, which would silently reintroduce the bug.
- When creating the list because it doesn't exist, create it *in the folder*
  (`clickup_create_list_in_folder`) rather than at space level.
- Regardless of `folder`, add the step-3-style ambiguity guard: **>1 matching list → stop and
  ask**, never guess. This is the part that matters most; it turns a silent
  wrong-list write into a loud refusal even for consumers who never set `folder`.
- `folder` stays optional and absent-by-default, so single-project spaces are unaffected and
  the change is purely additive for existing consumers.

Mirror the change into `.claude/skills/speckit-clickup-provision/SKILL.md` (the wiring
fidelity test covers the command/skill pair) and document the key in the plug README's
Configure section.

## Current mitigation (consumer-side, already in place)

Both affected repos state `folder:` in their committed `clickup-config.yml` **now**, ahead of
any release that reads it — config resolution is prompt-layer YAML reading with no schema, so
an unrecognised key is inert and becomes live the moment this ships:

- `clients/mcds/forte/tonic` → `folder: "Tonic v1"`, `list: "Roadmap"`
- `clients/mcds/forte/ledger` → `folder: "Ledger"`, `list: "Roadmap"`

Until then the standing constraint is **do not run `/speckit-specify` in either repo**. Both
config files carry that warning inline so it is discoverable without this document.

## Release mechanics (so they aren't rediscovered)

Per [docs/RELEASING.md](../../../docs/RELEASING.md): one scripted action,
`bash .specify/scripts/bash/release.sh <version>` from a clean `main`, doing
preflight → stamp → gate → build → scan → catalog → publish. Rehearse with `--dry-run`
first (repo untouched; emits `dist/catalog.local.json` for an offline install E2E).

Two consequences worth planning around:

- **Lockstep versioning** — all four extensions bump together, so `engine`, `git-lifecycle`
  and `review-loop` ship a new version too even though only `clickup` changed.
- **Catalog cache** — consumers see the new version *up to an hour later*, with no refresh
  flag. Both tonic and ledger then need `specify extension update`, and the
  `/speckit-specify` block stays in force until they have it.

## Why deferred

It cannot affect any existing feature (manifest-addressed), and it only triggers on a new
spec in one of two known repos, both of which now carry the constraint in their config. The
consumer-side `folder:` keys are already written, so shipping this is a pure code change with
no consumer migration. Worth doing before the next new spec in either repo — or immediately
if a third project joins the MCDS space.
