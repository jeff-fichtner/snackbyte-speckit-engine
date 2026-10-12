#!/usr/bin/env bash
# Tests for id-only-guard.sh — the check-gate guard that keeps name-based ClickUp container
# resolution out of the clickup plug (006 US4). Run: bash .specify/scripts/bash/id-only-guard.test.sh
set -uo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
G="$DIR/id-only-guard.sh"
FAIL_F="$(mktemp)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$FAIL_F"' EXIT
ok()  { printf '  ok   %s\n' "$1"; }
bad() { echo x >> "$FAIL_F"; printf '  FAIL %s — got %s\n' "$1" "$2"; }

fixture() { # $1=name; stdin = the command body. Prints the fixture root.
    local r="$TMP/$1"; mkdir -p "$r/commands" "$r/skills/speckit-clickup-x" "$r/skills/other"
    cat > "$r/commands/speckit.clickup.x.md"
    printf 'Read the command body and follow it.\n' > "$r/skills/speckit-clickup-x/SKILL.md"
    printf 'Unrelated skill: clickup_search with list_name is not scanned.\n' > "$r/skills/other/SKILL.md"
    printf '%s' "$r"
}
guard() { bash "$G" --commands "$1/commands" --skills "$1/skills" 2>&1; }
code()  { bash "$G" --commands "$1/commands" --skills "$1/skills" >/dev/null 2>&1; echo $?; }

r="$(fixture clean <<'EOF'
Call `clickup_get_list` with `list_id` and `workspace_id`, then `clickup_create_task`.
Statuses are set by name (the stated exception).
EOF
)"
[[ "$(code "$r")" == "0" ]] && ok "clean fixture passes (unrelated skills not scanned)" || bad "clean" "$(guard "$r")"

r="$(fixture g1 <<'EOF'
Line one passes `workspace_id`.
Call `clickup_get_list` with `list_name: config value`.
EOF
)"
o="$(guard "$r")"
[[ "$(code "$r")" == "1" ]] && grep -q 'speckit.clickup.x.md:2: G1' <<<"$o" && ok "G1: a *_name argument fails with file:line" || bad "g1" "$o"

r="$(fixture g2 <<'EOF'
Browse with `clickup_get_workspace_hierarchy` (`workspace_id`) to find the list.
EOF
)"
o="$(guard "$r")"
[[ "$(code "$r")" == "1" ]] && grep -q 'speckit.clickup.x.md:1: G2 clickup_get_workspace_hierarchy' <<<"$o" && ok "G2: a tool outside the allowlist fails, naming it" || bad "g2" "$o"

r="$(fixture g2b <<'EOF'
Create with `clickup_create_list` in the space (`workspace_id`).
EOF
)"
grep -q 'G2 clickup_create_list ' <<<"$(guard "$r") " && ok "G2: space-level clickup_create_list is not allowed" || bad "g2b" "$(guard "$r")"

r="$(fixture g3 <<'EOF'
Find the list named `config.list` under the space (`clickup_get_list`, `workspace_id`).
EOF
)"
o="$(guard "$r")"
[[ "$(code "$r")" == "1" ]] && grep -q 'speckit.clickup.x.md:1: G3' <<<"$o" && ok "G3: a config name key used as a locator fails" || bad "g3" "$o"

r="$(fixture g4 <<'EOF'
Call `clickup_get_list` with `list_id`.
EOF
)"
o="$(guard "$r")"
[[ "$(code "$r")" == "1" ]] && grep -q 'speckit.clickup.x.md:.*G4' <<<"$o" && ok "G4: ClickUp calls without workspace_id fail" || bad "g4" "$o"

r="$(fixture skill <<'EOF'
Clean body: `clickup_get_list` with `workspace_id`.
EOF
)"
printf 'Mirror: look it up with `space_name`.\n' > "$r/skills/speckit-clickup-x/SKILL.md"
o="$(guard "$r")"
grep -q 'speckit-clickup-x/SKILL.md:1: G1' <<<"$o" && ok "skill mirrors are scanned too" || bad "skill" "$o"

o="$(bash "$G" --bogus 2>&1)"; [[ $? == 2 ]] && ok "unknown flag → exit 2" || bad "usage" "$o"

o="$(bash "$G" 2>&1)"; rc=$?
[[ $rc == 0 ]] && ok "the real clickup plug passes the guard" || bad "real repo" "$o"

f="$(wc -l < "$FAIL_F" | tr -d '[:space:]')"; f="${f:-0}"
if [[ "$f" -ne 0 ]]; then echo "id-only-guard.test.sh: $f FAILED"; exit 1; fi
echo "id-only-guard.test.sh: all passed"
