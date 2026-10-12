---
description: "Inspect the real ClickUp workspace and propose a project-specific sync ruleset for approval; honored by sync when approved, else defaults apply"
argument-hint: "(no arguments)"
---

# ClickUp — Design Rules (US7)

Adapt the sync to *this* project's ClickUp conventions instead of forcing the project onto the
baked-in defaults. This command **inspects** the real workspace and **proposes** a tailored
ruleset for explicit human approval — it never silently reshapes the board. Opt-in enrichment:
with no approved ruleset, the baked-in defaults (from 001/US3) apply unchanged.

## Preconditions

- **The engine extension is installed** — `.specify/extensions/engine/scripts/bash/status-map.sh`
  exists. If not, **stop immediately with zero tracker writes**: "The clickup plug requires the
  engine extension. Install it: `specify extension add engine`."

## Steps

1. **Inspect the pinned list** (read-only, by ID) via the ClickUp MCP tools:
   - Resolve the target with `.specify/extensions/clickup/scripts/bash/targets.sh resolve`. If its
     `status` is not `ready` with `path: existing`, stop and say so: design rules need a pinned
     `list-id`. Run `/speckit-clickup-provision` first.
   - `clickup_get_list` (statuses) and `clickup_get_custom_fields`, each with `list_id` = the
     pinned `listId` and `workspace_id` = `workspaceId`. Do not browse the hierarchy, and do not
     look anything up by name.
   - Learn: the list's actual statuses (for the six-state mapping, by name, the stated
     exception) and any custom fields.

2. **Propose a ruleset** — present, for the user's approval, a concrete proposal covering:
   - the six logical states → this list's actual status names (the `statuses:` mapping),
   - whether user stories map to subtasks vs. tags vs. lists (default: subtasks),
   - what the card body emphasizes, and any custom-field usage.
   Show it as a diff/summary and **ask for explicit approval**. Never apply board-reshaping changes
   without a yes (FR-025).

3. **On approval** — record the ruleset as config the sync honors: write the resolved `statuses:`
   block into `clickup-config.yml` (committed, consumer-owned — preserved across `specify
   extension update`) and any additional rules into a `rules:` block there (or the manifest).
   With no approved ruleset present, sync uses the baked-in defaults unchanged (FR-026).

4. **Reject constitution-violating rules** — if a proposed rule would break a constitution
   principle (e.g. require two-way sync, or move tracker I/O out of the plug), **reject it** and
   explain; do not honor it (FR-027).

## Never
- Never silently applies board-reshaping changes — always propose + confirm.
- Never honors a ruleset that violates a constitution principle.
- Never removes the baked-in defaults — designed rules layer over them; absent, defaults stand.
