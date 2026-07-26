# Backlog: Stale lifecycle markers — later activity never invalidates earlier claims

**Status**: Backlog (not yet specified — do NOT run `/speckit-specify` here yet).
**Stop-gap shipped 2026-07-25**: the peel rule below is implemented as prompt-layer
instructions in the sync command's markers step (speckit.clickup.sync.md). What remains
backlogged: hardening it into tested deterministic logic (a `scripts/bash` helper the prompt
calls, with unit coverage — Constitution V), and any richer reopen semantics for `done`.

## The problem, plainly

Card status comes from sticky-note markers the syncs record in the feature manifest
(`analyzed`, `implementStarted`, `verifyPassed`, `closedOut`). Once stuck on, a note is never
peeled off — so redoing earlier work leaves later claims standing:

- Verify passes (card `in-review`), then more code lands → card still says `in-review`,
  but the new code was never certified. The board lies to reviewers.
- Analyze runs (card `ready`), then the spec/tasks are rewritten → card still says `ready`,
  but the new design was never analyzed.

## The sketched fix (from the 2026-07-25 discussion)

When a sync runs at a moment that invalidates a later claim, clear that claim's marker
(`manifest.sh set-lifecycle --key <k> --value false`); derive-status stays a pure reader:

- `after_specify` / `after_clarify` / `after_tasks` → clear `analyzed` + `verifyPassed`
- `after_analyze` → clear `verifyPassed` (design moved since certification)
- `before_implement` / `after_converge` → clear `verifyPassed` (new code voids the cert;
  the auto-chain re-certifies immediately, so the honest window is brief)
- `closedOut` → never auto-cleared; reopening `done` is an explicit human act
- `implementStarted` → stays sticky (decided): once code exists, `in-development` is the
  truthful floor; a mid-build spec tweak should not drop the card back to `in-design`

Plus derive-status test cases for the two regression paths (in-review + new implement →
in-development; ready + re-tasks → in-design).

## Why deferred

Single-maintainer flows rarely loop back after verify, and the auto-chain re-earns the
markers quickly when they do. Becomes worth fixing when others consume the board state
(friends' repos, real reviewers) or when a loop-back actually bites.
