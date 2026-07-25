# Backlog: Lifecycle profiles — configurable weight, model, and verbosity

**Status**: Backlog (not yet specified — do NOT run `/speckit-specify` here yet). Depends on
`002-clickup-lifecycle` being built and working.

## The idea

`002` specifies **the heaviest** version of the engine: every command syncs, a recursive
self-review runs, everything testable gets tested, an honest handoff is produced, close-out is a
full ceremony. That is the maximal, most-thorough lifecycle — correct as the default target, but
not what everyone will want every time.

This backlog is the counterpart: make the lifecycle **configurable / optionally lighter**, so
people can interact with the engine in different ways depending on cost, speed, and how much
hand-holding they want. `002` is the ceiling; this makes the floor reachable.

## Scope this backlog captures

### 1. Optional / skippable steps

Let a project (or a run) turn heavy steps off. The recursive self-review, the full E2E sweep, the
per-command sync, the analyze-autofix pass — each should be individually optional, so a lightweight
run can skip what it doesn't need. The heavy path stays the default; lightness is opt-in.

### 2. Model selection (cost)

Different steps could run on different models. Expensive, high-reasoning work (design review,
verification) might warrant a stronger model; mechanical steps (status sync, formatting) a cheaper
one. Let the profile declare which model tier each step uses, so a user trades cost for depth
deliberately.

### 3. Verbosity / interaction level

Some users want a terse, few-tokens, low-interaction run ("just do it, tell me when done"); others
want the full interactive, explain-every-step experience. A profile sets the verbosity and how
interactive the engine is (how often it stops to ask vs. proceeds on sensible defaults).

### 4. Profiles (bundling the above)

Bundle the three axes into named **profiles** — e.g. `thorough` (the 002 default: all steps,
strong models, interactive), `fast` (skip optional reviews, cheaper models, terse), `ci` (no
interaction at all). A user picks a profile per project or per run instead of tuning every knob.

## Open questions (resolve when specifying)

- Per-project config, per-run flag, or both? (Likely both — a project default profile, overridable
  per run.)
- Where do profiles live — an engine-level `profiles.yml`, the existing config, or the manifest?
- Which steps are safe to make optional without breaking the lifecycle's correctness guarantees
  (e.g. can you skip verification and still legitimately reach `in-review`? probably not — some
  steps are load-bearing for a state transition and cannot be skipped, only others).
- How does model/verbosity selection interact with the plug boundary? (Plugs shouldn't care about
  the profile; this is engine-level.)
- Does a lighter profile change what a client sees on the tracker, or only how the AI got there?
  (Probably only the "how" — the card lifecycle should look the same regardless of profile.)

## Why this is separate from 002

`002` must first define the full, correct, heavy lifecycle — you can't make something "optionally
lighter" until the heavy version exists and works. Profiles are a layer *on top of* a working
engine, not part of its initial definition. Folding them into `002` would stall it. Specify this
only once `002` is built and proven.
