#!/usr/bin/env bash
# id-only-guard.sh — fail the check gate if the clickup plug locates a ClickUp container by name
# (006 US4 / FR-012). Repo apparatus: checks this repo's source, never ships.
#
# Scans the plug's command bodies and the speckit-clickup-* skill mirrors:
#   G1  a *_name argument (list_name, space_name, folder_name) — the MCP's name lookups
#   G2  a clickup_* tool outside the ID-addressed allowlist below
#   G3  a container name key read as a locator (config.workspace / .space / .folder / .list)
#   G4  a file that names ClickUp tools but never passes workspace_id
#
# Usage: id-only-guard.sh [--commands DIR] [--skills DIR]
#   defaults: .specify/extensions/clickup/commands, .claude/skills
# Output: one `path:line: G<n> <message>` per violation. Exit 0 clean · 1 violations · 2 usage.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
CMD_DIR="$ROOT/.specify/extensions/clickup/commands"
SKILLS_DIR="$ROOT/.claude/skills"

# Changing this list is a deliberate, reviewed edit: every entry addresses ClickUp by ID.
ALLOW=" clickup_get_list clickup_get_folder clickup_create_list_in_folder clickup_create_task
 clickup_update_task clickup_get_task clickup_add_task_dependency clickup_remove_task_dependency
 clickup_get_custom_fields clickup_create_task_comment "
ALLOW=" $(echo $ALLOW) "   # one space between entries, so the membership test below is exact

while [[ $# -gt 0 ]]; do case "$1" in
    --commands) CMD_DIR="$2"; shift 2 ;;
    --skills)   SKILLS_DIR="$2"; shift 2 ;;
    -h|--help)  sed -n '2,14p' "$0"; exit 0 ;;
    *) echo "id-only-guard: unknown argument $1" >&2; exit 2 ;;
esac; done
[[ -d "$CMD_DIR" ]] || { echo "id-only-guard: commands dir not found: $CMD_DIR" >&2; exit 2; }

files=()
for f in "$CMD_DIR"/*.md "$SKILLS_DIR"/speckit-clickup-*/SKILL.md; do [[ -f "$f" ]] && files+=("$f"); done
[[ ${#files[@]} -gt 0 ]] || { echo "id-only-guard: nothing to scan under $CMD_DIR" >&2; exit 2; }

violations=0
report() { echo "$1"; violations=$((violations + 1)); }

for f in "${files[@]}"; do
    rel="${f#"$ROOT"/}"
    while IFS=: read -r ln _; do
        report "$rel:$ln: G1 passes a *_name argument — locate containers by ID"
    done < <(grep -nE '(^|[^a-z_])(list_name|space_name|folder_name)([^a-z_]|$)' "$f" || true)

    while IFS=: read -r ln tool; do
        case "$ALLOW" in *" $tool "*) ;; *) report "$rel:$ln: G2 $tool is not an ID-addressed tool (allowlist in id-only-guard.sh)" ;; esac
    done < <(grep -noE 'clickup_[a-z_]+' "$f" || true)

    while IFS=: read -r ln _; do
        report "$rel:$ln: G3 reads a container name key as a locator — use the *-id key"
    done < <(grep -nE 'config\.(workspace|space|folder|list)([^a-z_-]|$)' "$f" || true)

    if grep -qE 'clickup_[a-z_]+' "$f" && ! grep -q 'workspace_id' "$f"; then
        report "$rel:1: G4 names ClickUp tools but never passes workspace_id"
    fi
done

if [[ $violations -gt 0 ]]; then
    echo "id-only-guard: $violations violation(s)" >&2
    exit 1
fi
echo "id-only-guard: clean (${#files[@]} files)"
