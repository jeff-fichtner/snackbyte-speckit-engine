#!/usr/bin/env bash
# Tests for targets.sh — layered config resolution, the ID-only rules, and the list pin.
# Run: bash .specify/extensions/clickup/scripts/bash/targets.test.sh
set -uo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
T="$DIR/targets.sh"
FAIL_F="$(mktemp)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$FAIL_F"' EXIT
ok()  { printf '  ok   %s\n' "$1"; }
bad() { echo x >> "$FAIL_F"; printf '  FAIL %s — got %s\n' "$1" "$2"; }

# Ambient overrides must not leak into the tests.
for v in $(env | grep -oE '^SPECKIT_CLICKUP_[A-Z_]+' || true); do unset "$v"; done

newdir() { # fresh config dir with the shipped-defaults layer (runs in $(…), so no counters)
    local d; d="$(mktemp -d "$TMP/c.XXXXXX")"
    cat > "$d/extension.yml" <<'EOF'
extension:
  id: clickup
config:
  defaults:
    enabled: true
    provenance-mode: "A"
hooks:
  after_specify:
    - command: speckit.clickup.provision
EOF
    printf '%s' "$d"
}
resolve() { bash "$T" resolve --config-dir "$1" 2>/dev/null; }
rc()      { bash "$T" resolve --config-dir "$1" >/dev/null 2>&1; echo $?; }
field()   { resolve "$1" | jq -r ".$2 // empty"; }
errs()    { resolve "$1" | jq -r '.errors[]?'; }

echo "== layered reader =="
d="$(newdir)"
printf 'workspace-id: "1"\nspace-id: "2"\nlist-id: "3"\n' > "$d/clickup-config.yml"
[[ "$(resolve "$d" | jq -c .)" == '{"status":"ready","path":"existing","workspaceId":"1","spaceId":"2","listId":"3"}' ]] \
    && ok "committed layer → ready/existing" || bad "committed" "$(resolve "$d")"
printf 'list-id: "30"\n' > "$d/local-config.yml"
[[ "$(field "$d" listId)" == "30" ]] && ok "local-config overrides committed" || bad "local" "$(field "$d" listId)"
[[ "$(SPECKIT_CLICKUP_LIST_ID=300 field "$d" listId)" == "300" ]] && ok "env overrides local-config" || bad "env" "$(SPECKIT_CLICKUP_LIST_ID=300 field "$d" listId)"
[[ "$(SPECKIT_CLICKUP_WORKSPACE_ID=10 field "$d" workspaceId)" == "10" ]] && ok "env key mapping: workspace-id → SPECKIT_CLICKUP_WORKSPACE_ID" || bad "env-map" "$(SPECKIT_CLICKUP_WORKSPACE_ID=10 field "$d" workspaceId)"

d="$(newdir)"
printf 'workspace-id: "1"\nspace-id: "2"\nlist-id: "3"\n' > "$d/config.yml"
[[ "$(field "$d" listId)" == "3" ]] && ok "legacy config.yml read when no new file exists" || bad "legacy" "$(resolve "$d")"
printf 'list-id: "4"\n' > "$d/config.local.yml"
[[ "$(field "$d" listId)" == "4" ]] && ok "legacy config.local.yml overrides legacy config.yml" || bad "legacy-local" "$(field "$d" listId)"
printf 'workspace-id: "1"\nspace-id: "2"\nlist-id: "5"\n' > "$d/clickup-config.yml"
[[ "$(field "$d" listId)" == "5" ]] && ok "legacy files ignored once clickup-config.yml exists" || bad "legacy-ignored" "$(field "$d" listId)"

d="$(newdir)"
printf 'workspace-id: "1"\nspace-id: "2"\nlist-id: "<your-list-id>"\n' > "$d/clickup-config.yml"
[[ "$(rc "$d")" == "1" ]] && grep -q '^list-id: required' <<<"$(errs "$d")" && ok "<...> placeholder counts as absent" || bad "placeholder" "$(resolve "$d")"

d="$(newdir)"
cat > "$d/clickup-config.yml" <<'EOF'
workspace-id: "1"   # Workspace
space-id: 2 # products
folder-id: '7'
new-list-name: "Roadmap #2"   # a name, quoted, with a hash inside
statuses:
  open: "backlog"
  list-id: "999"
EOF
r="$(resolve "$d" | jq -c .)"
[[ "$r" == '{"status":"ready","path":"create","workspaceId":"1","spaceId":"2","folderId":"7","newListName":"Roadmap #2"}' ]] \
    && ok "quotes + trailing comments stripped; quoted '#' kept; indented keys ignored" || bad "parse" "$r"

d="$(newdir)"
printf 'workspace-id: "1"\nspace-id: "2"\nlist-id: "<placeholder>"\nlist-id: "8"\n' > "$d/clickup-config.yml"
[[ "$(field "$d" listId)" == "8" ]] && ok "last occurrence of a key wins" || bad "last-wins" "$(field "$d" listId)"

echo "== US1: existing list, disabled, unconfigured =="
d="$(newdir)"
printf 'workspace: "Workspace"\nworkspace-id: "1"\nspace: "products"\nspace-id: "2"\nlist: "Roadmap"\nlist-id: "3"\nfolder-id: "9"\n' > "$d/clickup-config.yml"
r="$(resolve "$d" | jq -c .)"
[[ "$r" == '{"status":"ready","path":"existing","workspaceId":"1","spaceId":"2","listId":"3"}' ]] \
    && ok "name keys beside their IDs are inert; folder-id unused when list-id set" || bad "inert" "$r"
grep -qE 'Roadmap|products' <<<"$r" && bad "no name in output" "$r" || ok "no container name in the resolved target"

d="$(newdir)"
printf 'enabled: false\nspace: "products"\n' > "$d/clickup-config.yml"
[[ "$(resolve "$d" | jq -c .)" == '{"status":"disabled"}' && "$(rc "$d")" == "0" ]] && ok "enabled: false → disabled, exit 0 (even if otherwise invalid)" || bad "disabled" "$(resolve "$d")"
[[ "$(SPECKIT_CLICKUP_ENABLED=true rc "$d")" == "1" ]] && ok "env enabled=true overrides committed false" || bad "enabled-env" "$(SPECKIT_CLICKUP_ENABLED=true rc "$d")"

d="$(newdir)"
[[ "$(resolve "$d" | jq -c .)" == '{"status":"unconfigured"}' && "$(rc "$d")" == "0" ]] && ok "no config at all → unconfigured" || bad "unconfigured" "$(resolve "$d")"
printf 'statuses:\n  open: "backlog"\nprovenance-mode: "A"\n' > "$d/clickup-config.yml"
[[ "$(field "$d" status)" == "unconfigured" ]] && ok "statuses/provenance only → unconfigured" || bad "unconfigured2" "$(resolve "$d")"

echo "== US2: loud failures, naming the key =="
d="$(newdir)"
cat > "$d/clickup-config.yml" <<'EOF'
space: "products"
list: "Roadmap"
statuses:
  open: "backlog"
EOF
[[ "$(rc "$d")" == "1" && "$(field "$d" status)" == "invalid" ]] && ok "name-only config (karaoke today) → exit 1, invalid" || bad "karaoke" "$(resolve "$d")"
e="$(errs "$d")"
grep -qx 'workspace-id: required' <<<"$e" && ok "names workspace-id" || bad "karaoke-ws" "$e"
grep -q '^space: "products" is a name — containers are located by ID only; set space-id' <<<"$e" && ok "names space / space-id" || bad "karaoke-space" "$e"
grep -q '^list: "Roadmap" is a name — containers are located by ID only; set list-id' <<<"$e" && ok "names list / list-id" || bad "karaoke-list" "$e"
[[ "$(wc -l <<<"$e" | tr -d ' ')" == "3" ]] && ok "all errors listed in one run" || bad "karaoke-count" "$e"
se="$(bash "$T" resolve --config-dir "$d" 2>&1 >/dev/null)"
grep -q 'workspace-id: required' <<<"$se" && ok "errors also on stderr" || bad "stderr" "$se"

d="$(newdir)"; printf 'space-id: "2"\nlist-id: "3"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == "workspace-id: required" ]] && ok "missing workspace-id named" || bad "no-ws" "$(errs "$d")"
d="$(newdir)"; printf 'workspace-id: "1"\nlist-id: "3"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == "space-id: required" ]] && ok "missing space-id named" || bad "no-space" "$(errs "$d")"
d="$(newdir)"; printf 'workspace-id: "1"\nspace-id: "2"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == "list-id: required — or set folder-id + new-list-name to create the list" ]] && ok "no list target → list-id required, names the create alternative" || bad "no-list" "$(errs "$d")"
d="$(newdir)"; printf 'workspace-id: "1"\nspace-id: "2"\nnew-list-name: "Roadmap"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == "list-id: required — or set folder-id + new-list-name to create the list" ]] && ok "new-list-name without folder-id → list-id required" || bad "name-no-folder" "$(errs "$d")"
d="$(newdir)"; printf 'workspace-id: "1"\nspace-id: "2"\nfolder-id: "7"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == "new-list-name: required with folder-id to create the list" ]] && ok "folder-id without new-list-name named" || bad "folder-no-name" "$(errs "$d")"
d="$(newdir)"; printf 'workspace-id: "1"\nspace-id: "2"\nlist-id: "Roadmap"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == 'list-id: "Roadmap" is not a ClickUp ID (IDs are numeric)' ]] && ok "non-numeric list-id named" || bad "non-numeric" "$(errs "$d")"
d="$(newdir)"; printf 'workspace-id: "1"\nspace-id: "2"\nfolder: "karaoke"\nlist-id: "3"\n' > "$d/clickup-config.yml"
[[ "$(errs "$d")" == 'folder: "karaoke" is a name — containers are located by ID only; set folder-id (keep the name as a comment)' ]] \
    && ok "folder name without folder-id is an error even with list-id set" || bad "folder-name" "$(errs "$d")"

echo "== US3: create path + pin =="
d="$(newdir)"
cat > "$d/clickup-config.yml" <<'EOF'
# header comment
workspace-id: "1"   # Workspace
space-id: "2"       # products
folder-id: "7"      # karaoke
new-list-name: "Roadmap"
statuses:
  open: "backlog"
EOF
[[ "$(field "$d" path)" == "create" && "$(field "$d" newListName)" == "Roadmap" ]] && ok "folder-id + new-list-name → ready/create" || bad "create" "$(resolve "$d")"
cp "$d/clickup-config.yml" "$TMP/before.yml"
out="$(bash "$T" pin-list --id 777 --name Roadmap --config-dir "$d")"; prc=$?
[[ "$prc" == "0" && "$out" == "pinned list-id 777 (Roadmap) in $d/clickup-config.yml" ]] && ok "pin-list exit 0 + message" || bad "pin-msg" "$prc $out"
dl="$(diff "$TMP/before.yml" "$d/clickup-config.yml" | grep -E '^[<>]')"
[[ "$dl" == $'< new-list-name: "Roadmap"\n> list-id: "777"  # Roadmap' ]] && ok "pin-list rewrites exactly the new-list-name line" || bad "pin-diff" "$dl"
r="$(resolve "$d" | jq -c .)"
[[ "$r" == '{"status":"ready","path":"existing","workspaceId":"1","spaceId":"2","listId":"777"}' ]] && ok "after the pin: ready/existing with the pinned ID" || bad "after-pin" "$r"
cp "$d/clickup-config.yml" "$TMP/pinned.yml"
bash "$T" pin-list --id 888 --name Roadmap --config-dir "$d" >/dev/null 2>&1; prc=$?
[[ "$prc" == "1" ]] && cmp -s "$TMP/pinned.yml" "$d/clickup-config.yml" && ok "pin-list refuses when list-id already set; file unchanged" || bad "pin-twice" "$prc"

d="$(newdir)"
printf 'workspace-id: "1"\nspace-id: "2"\nfolder-id: "7"' > "$d/clickup-config.yml"   # no trailing newline
printf 'new-list-name: "Roadmap"\n' > "$d/local-config.yml"
[[ "$(field "$d" path)" == "create" ]] && ok "create path with new-list-name from local-config" || bad "create-local" "$(resolve "$d")"
bash "$T" pin-list --id 555 --name Roadmap --config-dir "$d" >/dev/null; prc=$?
[[ "$prc" == "0" && "$(tail -n 2 "$d/clickup-config.yml")" == $'folder-id: "7"\nlist-id: "555"  # Roadmap' ]] \
    && ok "pin-list appends when the name came from an override layer" || bad "pin-append" "$(cat "$d/clickup-config.yml")"
[[ "$(field "$d" listId)" == "555" ]] && ok "appended pin resolves" || bad "append-resolve" "$(resolve "$d")"

d="$(newdir)"; printf 'new-list-name: "a\\tb"\n' > "$d/clickup-config.yml"
bash "$T" pin-list --id 12 --name 'a\tb' --config-dir "$d" >/dev/null
[[ "$(cat "$d/clickup-config.yml")" == 'list-id: "12"  # a\tb' ]] && ok "pin-list writes the name verbatim (no escape processing)" || bad "pin-verbatim" "$(cat "$d/clickup-config.yml")"

d="$(newdir)"; printf 'new-list-name: "R"\n' > "$d/clickup-config.yml"; cp "$d/clickup-config.yml" "$TMP/nn.yml"
bash "$T" pin-list --id abc --name R --config-dir "$d" >/dev/null 2>&1; prc=$?
[[ "$prc" == "1" ]] && cmp -s "$TMP/nn.yml" "$d/clickup-config.yml" && ok "pin-list refuses a non-numeric ID; file unchanged" || bad "pin-nonnum" "$prc"
d="$(newdir)"
bash "$T" pin-list --id 1 --name R --config-dir "$d" >/dev/null 2>&1; prc=$?
[[ "$prc" == "1" && ! -e "$d/clickup-config.yml" ]] && ok "pin-list refuses a missing config file" || bad "pin-missing" "$prc"

echo "== usage =="
bash "$T" >/dev/null 2>&1; [[ $? == 2 ]] && ok "no subcommand → exit 2" || bad "usage-none" "$?"
bash "$T" pin-list --name R >/dev/null 2>&1; [[ $? == 2 ]] && ok "pin-list without --id → exit 2" || bad "usage-pin" "$?"
bash "$T" resolve --bogus >/dev/null 2>&1; [[ $? == 2 ]] && ok "unknown flag → exit 2" || bad "usage-flag" "$?"

f="$(wc -l < "$FAIL_F" | tr -d '[:space:]')"; f="${f:-0}"
if [[ "$f" -ne 0 ]]; then echo "targets.test.sh: $f FAILED"; exit 1; fi
echo "targets.test.sh: all passed"
