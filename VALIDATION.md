# Validation checklist — what's proven, what's left

The engine (`002-clickup-lifecycle`) shipped 2026-07-14, signed off with a known manual
remainder. This file tracks that remainder. **Cross items off as you exercise them in other
projects**; delete the file once everything is checked.

## ✅ Verified automatically (no action needed)

- [x] **5 unit suites green** — `npm run check:all` (derive-status, status-map, manifest,
      parse-tasks, provenance) + shell lint.
- [x] **Six-state lifecycle end-to-end** — `open → in-design → ready → in-development →
      in-review → done` driven on a real feature dir.
- [x] **Live ClickUp round-trip** — card + 9 US-subtasks + checklists + dependency graph +
      provenance comment, all six status transitions accepted, read back from ClickUp.
- [x] **SC-006 idempotence on real data** — re-deriving all 11 elements → 0 writes.
- [x] **Six-state mapping against a real 9-status list** — 1:1, no degradation needed.
- [x] **no-jq fallbacks** — covered via the `CLICKUP_NO_JQ=1` hook.
- [x] **Scaffolding-only (Constitution IV)** — no tracker refs leak into shipped app code.
- [x] **`/speckit-verify` + `/speckit-close`** — both ceremonies dogfooded on 002 itself.

## ☐ Left to verify (the signed-off manual slice)

Each needs a fixture I couldn't build without touching your board or a fresh repo.

- [ ] **Degenerate-list 3-state fallback** (quickstart Scenario 2 · SC-011 · FR-015)
      Unit-tested, never run live. **How**: make a ClickUp list with only ~3 statuses, point a
      repo's `config.yml` at it, run provision + sync. Expect: the six logical states collapse
      onto the three, the sync reports the degradation, nothing fails.
- [ ] **Provision fail-loud on an unusable status set** (carried over from 001 · SC-007)
      **How**: a list that can't express even three distinct states → provision must stop, name
      exactly what's missing, and write nothing.
- [ ] **Manual-item non-clobber** (quickstart Scenario 6 · SC-008 · FR-022)
      Structurally guaranteed (manifest-absence), never proven live. **How**: hand-make a card in
      the shared list, run a sync. Expect: untouched, uncounted; spec-driven cards still reconcile.
- [ ] **Consolidated spine in a clean repo** (quickstart Scenario 8 · SC-015 · US9)
      **How**: install the engine into a fresh Spec Kit repo. Expect: all four extensions (post
      2026-07-26 merge) available from the one engine; the review module works on its `spec`,
      `analysis`, and `code` targets;
      `agent-context` (upstream) still installable alongside, unbroken.
- [ ] **Plug seam / zero-plug** (quickstart Scenario 9 · SC-013 · FR-032)
      **How**: set the ClickUp plug `enabled: false`. Expect: the lifecycle still runs, sync is a
      silent no-op (not an error). *Note*: the local plug + multi-plug broadcasting are
      deliberately **unbuilt** (research Decision 7) — only the seam exists.
- [ ] **Prompts as agent instructions, cold** (US8/US2 ceremonies)
      I followed my own prompts successfully — real evidence, but not independent. **How**: have a
      fresh agent session run `/speckit-verify` and `/speckit-close` on a feature it didn't build.
- [ ] **Every-command sync across a full real feature** (SC-005 · FR-013)
      002 was synced after the fact. **How**: run a *new* feature from `/speckit-specify` onward
      and watch the card advance on each command.
- [ ] **US7 design-rules live** (FR-025–027)
      **How**: run `/speckit-clickup-design-rules` against a real workspace; it should propose a
      ruleset and wait for approval — never silently reshape the board.
- [ ] **US6 Option B** (native GitHub integration · FR-024a)
      Deliberately unbuilt; Option A ships. The `provenance-mode` seam exists so B tacks on
      without reworking A. **How**: only if/when you want ClickUp's first-party commit links.

## Notes

- Bugs already found + fixed by testing (don't re-hunt these): `ready`/`in-development` derivation
  gap (→ `implementStarted` marker) · missing exec bits on new helpers · provenance selecting by
  commit message instead of spec-dir path · `set-card` dropping `provenanceHash`.
- Structural changes you make while testing elsewhere belong back in `specs/002-clickup-lifecycle/`
  (spec + contracts), not just in the code.
