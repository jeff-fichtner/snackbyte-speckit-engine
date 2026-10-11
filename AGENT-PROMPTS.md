# Agent prompts

Copy-paste prompts for when an agent misbehaves against this engine. Each one is
self-contained — paste it as-is; the agent does not need to have read this file.

## A mandatory hook was skipped

**When to use it:** an agent finishes a lifecycle phase and reports completion without the
next step happening — no clarify after specify, no tasks after plan, no verify after
converge, no ClickUp card movement. Often it printed an `## Extension Hooks` block with an
`EXECUTE_COMMAND:` line and stopped there.

**Why it happens:** that block *looks* like a directive handed off to a runtime. There is
no runtime. Nothing in this project parses `EXECUTE_COMMAND:`, and `auto_execute_hooks:
true` in [`.specify/extensions.yml`](.specify/extensions.yml) does not execute anything. A
hook runs only when the agent invokes the command itself. Emitting the block is the
failure mode, not the dispatch.

```text
You reported that phase complete without dispatching its mandatory post-execution hooks.

Printing an "## Extension Hooks" block — including any line beginning `EXECUTE_COMMAND:` —
does not run anything. There is no hook executor in this project; nothing parses that
marker. A hook runs only when you invoke the command yourself, as a real tool call, in
this session.

Do this now, before anything else:

1. Read `.specify/extensions.yml`. Find the entries under `hooks.<event>` for the event
   you just finished — `after_specify`, `after_clarify`, `after_plan`, `after_tasks`,
   `after_analyze`, `after_implement`, `after_converge`, `after_verify`, or `after_close`.
2. Keep every entry with `optional: false` whose `enabled` is not `false`. Those are
   mandatory. Sort them by `priority`, ascending.
3. Invoke each one, in that order, using whatever command-invocation mechanism actually
   works for you in this session (`/speckit-clickup-sync`, `/skill:speckit-clickup-sync`,
   `$speckit-clickup-sync`, …). Command ids in the YAML use dots; the invocable form uses
   hyphens — `speckit.clickup.sync` → `speckit-clickup-sync`. Wait for each to finish
   before starting the next.
4. Do not re-run the phase work itself. Only the hooks.

Then report one line per hook: the command id, whether it actually ran, and what it
returned. If you could not invoke one, say so explicitly and stop — do not report the
phase complete.
```

## The chain stalled somewhere upstream

**When to use it:** the lifecycle has been quiet for a while, or the tracker card is
plainly behind the repo. The mandatory hooks chain — specify → clarify, plan → tasks →
analyze, implement → converge → verify — so a single skipped dispatch stops everything
after it with no error. Fixing only the most recent gap will not catch you up.

```text
The mandatory lifecycle hooks in this project chain into each other: each phase's hooks
trigger the next phase. One skipped dispatch silently halts the chain, and no later hook
ever fires — the repo and the tracker card drift apart with no error anywhere.

Audit and catch up:

1. Read `.specify/extensions.yml` and list every `hooks.<event>` entry with
   `optional: false` whose `enabled` is not `false`.
2. Find the active feature: `.specify/feature.json` → `feature_directory`.
3. Work out which lifecycle events have actually happened, from what is on disk in that
   directory: `spec.md` exists (specify), a `## Clarifications` section with entries
   (clarify), `plan.md` (plan), `tasks.md` (tasks), tasks checked off (implement), and the
   markers in `.clickup-sync.json` → `lifecycle`: `analyzed`, `implementStarted`,
   `verifyPassed`, `closedOut`.
4. For each event that has happened, decide whether its mandatory hooks left their trace.
   The ClickUp sync's trace is a current `card.hash` / `userStories[].hash` and the
   matching `lifecycle` marker in `.clickup-sync.json`; a lifecycle-advancing command's
   trace is the artifact it was supposed to produce.
5. Report the gaps first — which event, which hook, what evidence says it never ran — and
   wait for my go-ahead before running anything. Then dispatch the missing hooks in
   lifecycle order, oldest event first, priority ascending within an event, waiting for
   each to finish.

Report one line per hook you run: command id, whether it actually ran, what it returned.
Do not silently skip one because it looks redundant — say so and let me decide.
```

## Notes

- These are stopgaps for a real design problem: the mandatory-hook instructions in the
  rendered skill files are shaped like a report format rather than an action, and the
  weakest wording sits on the most load-bearing events (`after_analyze`, `after_converge`).
  The durable fix is to rewrite that block and retire the `EXECUTE_COMMAND:` marker.
- The second prompt deliberately stops for approval before it changes anything. A
  catch-up sweep can move a tracker card several states at once; that should be a
  decision, not a side effect.
