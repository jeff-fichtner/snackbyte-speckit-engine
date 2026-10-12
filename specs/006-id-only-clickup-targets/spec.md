# Feature Specification: ID-only ClickUp targets

**Feature Branch**: `006-id-only-clickup-targets`

**Created**: 2026-10-11

**Status**: Draft

**Input**: User description: "Fix inbox #97cb94. The clickup plug locates ClickUp containers by ID
only. It should never have resolved anything by name. Workspace, space, folder and list are all
identified by ID in clickup-config.yml. Names may stay as human-readable comments; a name with no
ID is an error, never a lookup; a missing required ID fails loudly at provision time, naming the
key. Where a list doesn't exist yet, a folder ID says where to create it. Design how the created
list's ID gets pinned afterwards, so the next feature uses the ID rather than finding it again.
Status mapping is by name because ClickUp's API sets status by name — the one stated exception."

**History**: [specs/backlog/006-folder-scoped-list-resolution](../backlog/006-folder-scoped-list-resolution/BACKLOG.md)
records how the bug was found (2026-08-29). It is the history, not the design: its sketched fix
(an optional `folder` name key plus an ambiguity guard) is superseded by the ruling below.

## Clarifications

### Session 2026-10-11

- Ruling (Jeff, verbatim intent): the ClickUp plug locates containers **by ID only** and should
  never have resolved anything by name. Workspace, space, folder and list are all identified by
  ID in `clickup-config.yml`. Names may stay as human-readable comments. A name with no ID is an
  error, never a lookup. A missing required ID fails loudly at provision time, naming the key.
  Where a list does not exist yet, a folder ID says where to create it. The created list's ID is
  pinned afterwards so the next feature uses the ID rather than finding it again.
- Ruling: **status mapping is by name** — the one stated exception — because ClickUp's API sets a
  task's status by its name. Names are only ever resolved *inside* a list already located by ID,
  where status names are unique.
- Agreed (Jeff): putting container IDs in the committed plug config conflicts with Constitution
  Principle IV ("runtime tracker IDs are confined to the per-feature manifest") and II ("config
  names only WHERE"). Both are amended by this feature rather than worked around.
- Agreed (Jeff): this repo's own ClickUp target (space `90146433590`, list `901417991049`) no
  longer exists after a workspace reorganisation. This repo re-pins, by ID, to
  `platforms / speckit-engine / Roadmap` (workspace `90141363864`, space `90146747064`, folder
  `901411097129`, list `901418532190`) and provisions this feature there.
- Agreed (Jeff): end-to-end tests delete everything they create. Tasks are deleted through the
  connected ClickUp MCP. The connected MCP cannot delete lists, so the one test list the create
  path makes is deleted through Jeff's self-hosted ClickUp MCP (which has `clickup_delete_list`),
  after Jeff confirms the exact list ID.
- Ruling (Jeff): no defensive cross-checks. A mistyped ID is a well-written system not being
  used; the plug does not assume the user or agent is wrong. So the configured `list-id` is
  authoritative and is not cross-checked against `space-id` or `folder-id`, and there is no guard
  against re-pinning mid-feature. Validation stays where the ruling puts it: missing keys, names
  without IDs, and an ID that does not exist (a real failure, not suspicion).
- Out of scope, recorded so it is not folded in: issue #1 (the card hash ignores body content, so
  prose-only spec edits never re-render the card).

## User Scenarios & Testing *(mandatory)*

### User Story 1 - A repo provisions into exactly the list it pins (Priority: P1)

A maintainer of a repo that shares a ClickUp space with other products (e.g. snackbyte-karaoke,
whose `products` space holds fourteen lists all named `Roadmap`) pins its workspace, space and list
by ID in `clickup-config.yml`. Every new feature's provision lands in that list — no lookup, no
guess, no chance of adopting another product's board.

**Why this priority**: this is the defect. Today a new spec in any of those repos can silently
write its card into another product's list, and the mistake is durable (recorded in the manifest).

**Independent Test**: with karaoke's IDs pinned (workspace `90141363864`, space `90146746995`,
list `901421288946`), run provision on a fresh feature; the manifest records list
`901421288946`, the card is created in that list, and no name-based lookup tool is called.

**Acceptance Scenarios**:

1. **Given** a config pinning `workspace-id`, `space-id` and `list-id`, **When** provision runs,
   **Then** the manifest's `listId` equals the pinned `list-id` and the feature-card is created in
   that list.
2. **Given** the same config with fourteen same-named lists in the space, **When** provision runs,
   **Then** the result is identical — the other lists' names are never consulted.

---

### User Story 2 - A config without IDs fails loudly, naming the key (Priority: P1)

A consumer still on the old name-based config (`space: "products"`, `list: "Roadmap"`) runs a new
spec. Provision refuses before touching ClickUp and says exactly what to set: which key is
missing, that names are no longer lookups, and where the ID can be found.

**Why this priority**: without it, the fix silently degrades for every un-migrated consumer — the
precise failure mode the ruling forbids.

**Independent Test**: point provision at karaoke's current (name-only) config; it exits non-zero
with a message naming `workspace-id`, `space-id` and `list-id`, and makes zero ClickUp calls.

**Acceptance Scenarios**:

1. **Given** `list: "Roadmap"` and no `list-id`, **When** provision runs, **Then** it fails naming
   both `list` and `list-id`, stating that a name is never a lookup.
2. **Given** no `workspace-id` (or no `space-id`), **When** provision runs, **Then** it fails
   naming the missing key.
3. **Given** `list-id: "Roadmap"` (a name pasted into an ID key), **When** provision runs,
   **Then** it fails naming `list-id` and stating that IDs are numeric.
4. **Given** a pinned `list-id` that does not exist in the pinned workspace, **When** provision
   runs, **Then** it fails naming `list-id` and the ID that was not found.

---

### User Story 3 - A new product's first feature creates its list and pins it (Priority: P2)

A brand-new repo has a folder in ClickUp but no list yet. Its config pins `workspace-id`,
`space-id` and `folder-id`, plus `new-list-name` for the list to create. The first provision
creates the list in that folder and immediately pins the new list's ID into `clickup-config.yml`.
Every later feature uses the pinned ID: no second list, and no finding it again.

**Why this priority**: needed for new products, but every existing consumer already has a list
and is fully served by Stories 1–2.

**Independent Test**: with `folder-id` + `new-list-name` and no `list-id`, run provision twice on
two features. The first creates exactly one list in the folder and rewrites the config to
`list-id: "<new id>"`; the second creates no list and records the same `listId`.

**Acceptance Scenarios**:

1. **Given** `folder-id` + `new-list-name` and no `list-id`, **When** provision runs, **Then** one
   list named `new-list-name` is created inside `folder-id` (never at space level) and
   `clickup-config.yml` now carries `list-id` with the new ID, the name kept as a comment.
2. **Given** that pinned config, **When** provision runs for the next feature, **Then** no list is
   created and the manifest records the pinned ID.
3. **Given** the pin was written, **When** the feature's pre-implementation checkpoint commit
   runs, **Then** the config change is part of that commit, so the pin reaches the branch with
   the spec.
4. **Given** no `list-id` and no `folder-id`, **When** provision runs, **Then** it fails naming
   `list-id` and stating that `folder-id` + `new-list-name` is the way to create one.

---

### User Story 4 - The check gate stops name resolution from coming back (Priority: P2)

A future change to the plug reintroduces a name-based container lookup — a `list_name` argument, a
hierarchy browse matched on name, a space-level create. The repo's check gate fails and says
where.

**Why this priority**: the ruling is "never"; a regression test is what makes "never" hold after
this feature ships.

**Independent Test**: add a line passing `list_name` to a ClickUp tool in any plug command body;
`npm run check:all` fails, naming the file and line. Remove it; the gate passes.

**Acceptance Scenarios**:

1. **Given** a plug command or skill mirror that passes `list_name`, `space_name` or
   `folder_name` to a ClickUp tool, **When** the check gate runs, **Then** it fails naming file
   and line.
2. **Given** a plug command or skill mirror that calls a ClickUp tool outside the allowlist of
   ID-addressed tools, **When** the check gate runs, **Then** it fails naming the tool.
3. **Given** the config resolver, **When** its tests run, **Then** they prove a container name
   never becomes a locator in its output.

### Edge Cases

- **Folderless list**: a list that sits directly in a space has no folder. `list-id` + `space-id`
  is valid without `folder-id`; `folder-id` is only required on the create path.
- **`folder-id` given alongside `list-id`**: the list ID is authoritative and `folder-id` is
  unused (it only says where to *create* a list). No cross-check (Clarifications).
- **Name key alongside its ID** (`list: "Roadmap"` and `list-id: "9014…"`): the name is inert
  documentation and is never read as a locator. It is not an error.
- **`new-list-name` present while `list-id` is set**: inert; the pinned list is used.
- **Pin write fails after the list was created**: provision stops, reports the new list's ID and
  the exact line to add, and makes no further tracker writes — so a rerun cannot silently create a
  second list without the human seeing the first.
- **Value comes from an override layer** (env or `local-config.yml`): resolution is unchanged;
  the pin is always written to the committed `clickup-config.yml`.
- **`<...>` placeholder** in any ID key: treated as absent (existing rule).
- **Multiple workspaces on the ClickUp account**: every ClickUp call passes the workspace ID, so the
  connected MCP never has to choose one.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: The ClickUp plug MUST locate the workspace, space, folder and list **only** by the IDs
  in its config (at provision) or in the feature manifest (at sync, verify and close). No command
  body, skill mirror or script may look up a container by its name.
- **FR-002**: The config contract MUST use these location keys: `workspace-id`, `space-id`,
  `folder-id`, `list-id`, plus `new-list-name` (the name to give a list provision creates). Every
  `*-id` value MUST be a numeric ClickUp ID. Container names MAY appear as YAML comments.
- **FR-003**: `workspace-id` and `space-id` MUST be present. A list target MUST be given as either
  `list-id`, or `folder-id` + `new-list-name`. Any missing required key MUST fail provision before
  any ClickUp call, naming the key, with zero tracker writes.
- **FR-004**: A container name key (`workspace`, `space`, `folder`, `list`) present without its
  `*-id` counterpart MUST be an error naming both keys and stating that a name is never a lookup.
  It MUST never trigger a lookup. With its counterpart present it is inert.
- **FR-005**: A non-numeric value in any `*-id` key MUST be an error naming the key.
- **FR-006**: Before any write, provision MUST read the configured list (or, on the create path,
  the folder) by ID. If ClickUp reports it not found, provision MUST stop, naming the key and the
  ID. No other cross-check is made (Clarifications: no defensive cross-checks).
- **FR-007**: When `list-id` is absent, provision MUST create the list inside `folder-id`, named
  `new-list-name`. It MUST NOT create a list at space level and MUST NOT create a space or folder.
- **FR-008**: Immediately after creating a list, and before any other tracker write, provision MUST
  pin the new ID in the committed `clickup-config.yml`: `new-list-name: "<name>"` is replaced by
  `list-id: "<new id>"  # <name>`. Every later provision uses the pinned ID. If the pin cannot be
  written, provision MUST stop and print the new ID and the exact line to add.
- **FR-009**: The pre-implementation checkpoint commit MUST include repo-level extension config
  files that changed during the lifecycle (committed `<extension>-config.yml`, never machine-local
  or gitignored config), so a pin written at provision reaches the branch with the spec.
- **FR-010**: Every ClickUp MCP call the plug makes MUST pass the workspace ID.
- **FR-011**: Status mapping is the **one stated exception** to ID-only: the six logical states map
  to status **names**, because ClickUp sets a task's status by name. Names are resolved only within
  the list located by ID, and every mapped name MUST exist on that list (existing fail-loud rule).
- **FR-012**: The check gate MUST fail if any plug command body or skill mirror passes
  `list_name`, `space_name` or `folder_name` to a ClickUp tool, or names a ClickUp tool outside an
  explicit allowlist of ID-addressed tools (hierarchy browsing, search and space-level list create
  are not on it). The failure MUST name the file and the offending line or tool.
- **FR-013**: Config resolution (layering, required-key checks, the name-without-ID error, numeric
  validation, choosing between the existing-list and create paths) and the pin rewrite MUST live in
  a tested script (Constitution V). Provision's command body consumes the script's output and
  embeds none of that logic.
- **FR-014**: The ask-once flow for an unconfigured repo MUST ask for IDs (`workspace-id`,
  `space-id`, and `list-id` or `folder-id` + `new-list-name`), say where they are visible in
  ClickUp, and write them to `clickup-config.yml`. It MUST NOT ask for names to look up.
- **FR-015**: `/speckit-clickup-design-rules` MUST inspect the pinned list by ID and MUST NOT browse
  the hierarchy to find it.
- **FR-016**: *(Withdrawn 2026-10-11: no defensive cross-checks — see Clarifications.)*
- **FR-017**: Constitution Principles II and IV MUST be amended. Config identifies WHERE by ID, never
  secrets. Tracker IDs may be committed in the plug's repo-level config (container IDs) and in the
  per-feature manifest (runtime item IDs), and nowhere else. A name never locates a container.
- **FR-018**: The plug README, `docs/CONSUMING.md` and `docs/MIGRATION.md` MUST document the ID
  contract: where each ID is visible in ClickUp, and how to migrate a name-based config. The skill
  mirrors of every changed command MUST match their command bodies.
- **FR-019**: The release scan MUST also forbid this repo's current real ClickUp IDs inside any
  archive.
- **FR-020**: This repo's own `clickup-config.yml` MUST pin its target by ID
  (`platforms / speckit-engine / Roadmap`).

### Key Entities

- **Plug config (`clickup-config.yml`)**: repo-level, committed. Holds the container IDs, optional
  `new-list-name`, `statuses`, `enabled`, `provenance-mode`. Overridable per machine by
  `local-config.yml` and env. Now also the home of the pinned list ID.
- **Resolved target**: the output of config resolution — workspace, space, optional folder, and
  either a list ID (existing-list path) or a folder ID + new list name (create path). Contains no
  name used as a locator.
- **Feature manifest (`specs/<feature>/.clickup-sync.json`)**: unchanged shape. Records the
  resolved workspace, space and list IDs plus the status mapping, card and subtasks.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: Zero code paths in the plug resolve a container by name, and the check gate fails
  when one is reintroduced (verified by deliberately reintroducing one).
- **SC-002**: A repo pinned to karaoke's IDs provisions into list `901421288946` on every run,
  verified live against the real hierarchy that holds fourteen same-named lists.
- **SC-003**: A config without IDs fails at provision with an error naming every missing key, and
  makes zero ClickUp calls.
- **SC-004**: On the create path, the first provision creates exactly one list in the pinned folder.
  A second provision creates none and records the same list ID.
- **SC-005**: End-to-end testing leaves nothing behind in ClickUp: every task and list it creates is
  deleted, and each deletion is confirmed by a read-back.

## Assumptions

- ClickUp container IDs (workspace, space, folder, list) are numeric; status IDs are not used.
- Status names are unique within a list, so a name lookup scoped to an ID-located list is
  unambiguous.
- One shared list per repo (unchanged from 001).
- Consumers update their own config. This feature edits no consumer repo; it files a request per
  consumer instead.
- The config contract change is breaking for every consumer, so it ships under a new major
  release version (proposed separately per `docs/RELEASING.md`).
