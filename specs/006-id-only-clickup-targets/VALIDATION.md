# Validation evidence: 006 ID-only ClickUp targets

Run 2026-10-11 against workspace `90141363864`, from a fresh consumer
(`specify init` → catalog add of the `release.sh 2.0.0 --dry-run` local catalog → all four
extensions installed, spec-kit CLI 1.0.8). Scenario numbers are those in
[quickstart.md](quickstart.md).

## Automated gate

| Check | Result |
|---|---|
| `npm run check:all` | **10 files passed, 0 failed** |
| `targets.test.sh` | 43 checks, all pass, under bash 5 and macOS `/bin/bash` 3.2.57 |
| `id-only-guard.test.sh` | 9 checks: G1–G4 fixtures fail, clean fixture passes, the real repo passes |
| `commit-spec-artifacts.test.sh` | 6 checks, under bash 5 and 3.2 |
| Release dry run (`2.0.0`) | 4 archives, **scan clean** with the extended `FORBIDDEN_CONTENT` |
| Shipped `scripts/bash/targets.sh` | Present in `clickup-2.0.0.zip`, mode `-rwxr-xr-x` |
| Guard over the consumer's **CLI-rendered** skills | `id-only-guard: clean (6 files)` |

## Live scenarios

| # | Scenario | Evidence | Result |
|---|---|---|---|
| 0 | Gate catches a reintroduced name lookup | Appended a `list_name` call to provision.md. `check:all` exit 1: `provision.md:148: G1 …`. Reverted: 10/10 green | ✅ |
| 1 | Karaoke provisions into `901421288946` | `resolve` → `ready/existing listId 901421288946`. `clickup_get_list(901421288946, ws)` found. Manifest `listId 901421288946`. Card `86bcgmjcq` read back in list `901421288946`, folder `901413565518` (karaoke). No hierarchy call | ✅ |
| 2 | Karaoke's **current** name-only config | `resolve` exit 1 with 3 errors: `workspace-id: required`; `space: "products" is a name …set space-id`; `list: "Roadmap" is a name …set list-id`. The script makes no ClickUp call | ✅ |
| 3 | Dead list ID | `SPECKIT_CLICKUP_LIST_ID=901417991049` → `resolve` ready (env layer wins). `clickup_get_list` → `Resource not found` → provision step 2 stops naming `list-id` | ✅ |
| 4 | Create path pins the list | `resolve` → `ready/create`. `get_folder(901411097129)` found. `create_list_in_folder` → **`901422173368`**. `pin-list` diff is exactly `new-list-name: "speckit-engine-e2e-delete-me"` → `list-id: "901422173368"  # speckit-engine-e2e-delete-me`. Re-`resolve` → `ready/existing 901422173368`; second feature's manifest `listId 901422173368`, no second list | ✅ |
| 5 | Is status-by-name required? | Status **ID** `p90146747064_Comiarr0` rejected by the connected MCP ("Status does not exist") **and by ClickUp's API directly** (self-hosted MCP, raw `PUT /task`: `400 ITEM_114 Status does not exist`). Set by name `in design` → read back `in design` | ✅ The exception is required |
| 6 | Cleanup | Tasks `86bcgmjcq` and `86bcgmjen` deleted; each read back `Resource not found`. Test list holds 0 tasks. Karaoke Roadmap `task_count` back to 1 (its pre-test value). **List `901422173368` awaits Jeff's confirmation** before deletion through the self-hosted MCP | ⏳ list |
| 7 | Pin reaches the checkpoint commit | `commit-spec-artifacts.test.sh`: the commit holds the spec dir + changed/new `*-config.yml`; it excludes `local-config.yml`, gitignored files, unrelated changes | ✅ |

## Found and fixed during verification

- `pin-list` passed the list name to awk via `-v`, which processes escapes: `a\tb` would have been
  pinned with a real tab. It now uses `ENVIRON`, with a regression test.
- `pin-list`'s message printed an unnormalised `scripts/bash/../..` path. It now prints the
  resolved config dir.

## Dogfood

This feature was itself provisioned by ID (before the code existed) into
`platforms / speckit-engine / Roadmap` (`901418532190`). Its card is
[ID-only ClickUp targets](https://app.clickup.com/t/86bcgk14k). It is the pipeline's normal card
and stays.
