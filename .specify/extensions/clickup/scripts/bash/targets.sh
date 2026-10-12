#!/usr/bin/env bash
# Resolve the ClickUp plug's target from its layered config — by ID only — and pin a created list.
#
# Pure repo-side logic: no ClickUp, no MCP. Provision consumes `resolve`'s JSON and makes the
# ClickUp calls itself (contracts: specs/006-id-only-clickup-targets/contracts/).
#
# Containers (workspace, space, folder, list) are located ONLY by the `*-id` keys. Container
# names are documentation: a name key (`workspace`, `space`, `folder`, `list`) without its ID is
# an error, never a lookup; beside its ID it is inert. `new-list-name` is the name for a list
# provision creates in `folder-id` — a creation input, not a locator.
#
# Layers, highest wins: env SPECKIT_CLICKUP_<KEY> (`-`→`_`, uppercased) > local-config.yml >
# clickup-config.yml > extension.yml `config.defaults`. Legacy config.local.yml / config.yml are
# read only when neither new file exists. Only top-level `key: value` lines are read; a `<...>`
# placeholder counts as absent; the last real value of a key in a file wins.
#
# Usage:
#   targets.sh resolve [--config-dir DIR]
#       Print the resolved target as JSON:
#         {"status":"ready","path":"existing","workspaceId","spaceId","listId"}
#         {"status":"ready","path":"create","workspaceId","spaceId","folderId","newListName"}
#         {"status":"disabled"}       enabled: false — the caller exits silently
#         {"status":"unconfigured"}   nothing set — the caller asks once for IDs
#         {"status":"invalid","errors":[...]}  (exit 1; each error also on stderr, key first)
#   targets.sh pin-list --id ID --name NAME [--config-dir DIR]
#       Pin a just-created list in the committed layer `resolve` reads (clickup-config.yml, or
#       legacy config.yml), creating it if missing: the `new-list-name:` line becomes
#       `list-id: "ID"  # NAME`, or that line is appended when the name came from another layer.
#       The file keeps its mode. Refuses (exit 1) a non-numeric ID or an already-pinned list-id.
#
# DIR defaults to this extension's directory. Exit 0 ok · 1 invalid/refused · 2 usage.
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

usage() { sed -n '2,30p' "$0" >&2; exit 2; }
die()   { echo "targets.sh: $*" >&2; exit 2; }

command -v jq >/dev/null 2>&1 || { echo "targets.sh: jq is required (brew install jq / apt-get install jq)" >&2; exit 2; }

SUB="" CONFIG_DIR="$SCRIPT_DIR/../.." PIN_ID="" PIN_NAME="" have_id=false
[[ $# -gt 0 ]] || usage
SUB="$1"; shift
case "$SUB" in resolve|pin-list) ;; -h|--help) usage ;; *) die "unknown subcommand '$SUB'" ;; esac
while [[ $# -gt 0 ]]; do
    case "$1" in
        --config-dir) [[ $# -ge 2 ]] || die "--config-dir needs a value"; CONFIG_DIR="$2"; shift 2 ;;
        --id)         [[ $# -ge 2 ]] || die "--id needs a value"; PIN_ID="$2"; have_id=true; shift 2 ;;
        --name)       [[ $# -ge 2 ]] || die "--name needs a value"; PIN_NAME="$2"; shift 2 ;;
        -h|--help)    usage ;;
        *)            die "unknown argument '$1'" ;;
    esac
done
[[ -d "$CONFIG_DIR" ]] || die "config dir not found: $CONFIG_DIR"
CONFIG_DIR="$(cd -- "$CONFIG_DIR" && pwd)"

# ---- flat reader -------------------------------------------------------------------------

PLACEHOLDER='^<.*>$'

# Print the value of top-level KEY in FILE: the last occurrence with a real value wins, so a
# blank or <...> placeholder line never shadows one. Strips surrounding quotes and an unquoted
# trailing comment.
file_value() { # $1=file $2=key
    [[ -f "$1" ]] || return 0
    awk -v key="$2" '
        index($0, key ":") == 1 {
            v = substr($0, length(key) + 2)
            sub(/^[ \t]+/, "", v)
            q = substr(v, 1, 1)
            if (q == "\"" || q == "'"'"'") {
                rest = substr(v, 2); end = index(rest, q)
                v = (end > 0) ? substr(rest, 1, end - 1) : rest
            } else {
                if (substr(v, 1, 1) == "#") v = ""
                sub(/[ \t]+#.*$/, "", v)
                sub(/[ \t\r]+$/, "", v)
            }
            if (v != "" && v !~ /^<.*>$/) { val = v; seen = 1 }
        }
        END { if (seen) printf "%s", val }
    ' "$1" | { IFS= read -r v || true; [[ "$v" =~ $PLACEHOLDER ]] && v=""; printf '%s' "$v"; }
}

# Print KEY from extension.yml's `config.defaults` block (4-space-indented under `  defaults:`).
default_value() { # $1=key
    local f="$CONFIG_DIR/extension.yml"
    [[ -f "$f" ]] || return 0
    awk -v key="$1" '
        /^config:/ { inc = 1; next }
        inc && /^[^ ]/ { inc = 0 }
        inc && /^  defaults:/ { ind = 1; next }
        ind && /^  [^ ]/ { ind = 0 }
        ind && index($0, "    " key ":") == 1 {
            v = substr($0, length(key) + 6); sub(/^[ \t]+/, "", v); sub(/[ \t]+#.*$/, "", v)
            gsub(/^["'"'"']|["'"'"']$/, "", v); printf "%s", v; exit
        }
    ' "$f"
}

LOCAL="$CONFIG_DIR/local-config.yml"
COMMITTED="$CONFIG_DIR/clickup-config.yml"
if [[ ! -f "$LOCAL" && ! -f "$COMMITTED" ]] \
   && [[ -f "$CONFIG_DIR/config.local.yml" || -f "$CONFIG_DIR/config.yml" ]]; then   # migration grace: legacy names
    LOCAL="$CONFIG_DIR/config.local.yml"
    COMMITTED="$CONFIG_DIR/config.yml"
fi

# Merged value of KEY across the layers (empty = absent everywhere).
get() { # $1=key
    local env_name v
    env_name="SPECKIT_CLICKUP_$(printf '%s' "$1" | tr 'a-z-' 'A-Z_')"
    v="${!env_name:-}"; [[ "$v" =~ $PLACEHOLDER ]] && v=""
    [[ -n "$v" ]] || v="$(file_value "$LOCAL" "$1")"
    [[ -n "$v" ]] || v="$(file_value "$COMMITTED" "$1")"
    [[ -n "$v" ]] || v="$(default_value "$1")"
    printf '%s' "$v"
}

is_id() { [[ "$1" =~ ^[0-9]+$ ]]; }

# ---- resolve -----------------------------------------------------------------------------

cmd_resolve() {
    local enabled; enabled="$(get enabled | tr '[:upper:]' '[:lower:]')"
    case "$enabled" in false|no|off|0) jq -nc '{status:"disabled"}'; return 0 ;; esac

    local ws sp fo li nl wsn spn fon lin
    ws="$(get workspace-id)"; sp="$(get space-id)"; fo="$(get folder-id)"; li="$(get list-id)"
    nl="$(get new-list-name)"
    wsn="$(get workspace)"; spn="$(get space)"; fon="$(get folder)"; lin="$(get list)"

    if [[ -z "$ws$sp$fo$li$nl$wsn$spn$fon$lin" ]]; then jq -nc '{status:"unconfigured"}'; return 0; fi

    local errors=()
    name_err() { errors+=("$1: \"$2\" is a name — containers are located by ID only; set $1-id (keep the name as a comment)"); }
    id_err()   { errors+=("$1: \"$2\" is not a ClickUp ID (IDs are numeric)"); }

    # workspace + space: always required
    local c id nm
    for c in workspace space; do
        if [[ "$c" == workspace ]]; then id="$ws"; nm="$wsn"; else id="$sp"; nm="$spn"; fi
        if [[ -z "$id" ]]; then
            if [[ -n "$nm" ]]; then name_err "$c" "$nm"; else errors+=("$c-id: required"); fi
        elif ! is_id "$id"; then id_err "$c-id" "$id"; fi
    done
    # folder: a name without its ID is an error wherever it appears
    if [[ -z "$fo" && -n "$fon" ]]; then name_err folder "$fon"; fi
    if [[ -n "$fo" ]] && ! is_id "$fo"; then id_err folder-id "$fo"; fi
    # list: list-id, or folder-id + new-list-name
    if [[ -n "$li" ]]; then
        is_id "$li" || id_err list-id "$li"
    elif [[ -n "$lin" ]]; then
        name_err list "$lin"
    elif [[ -z "$fo" ]]; then
        errors+=("list-id: required — or set folder-id + new-list-name to create the list")
    elif [[ -z "$nl" ]]; then
        errors+=("new-list-name: required with folder-id to create the list")
    fi

    if [[ ${#errors[@]} -gt 0 ]]; then
        printf '%s\n' "${errors[@]}" >&2
        printf '%s\n' "${errors[@]}" | jq -Rnc '{status:"invalid", errors:[inputs]}'
        return 1
    fi

    if [[ -n "$li" ]]; then
        jq -nc --arg w "$ws" --arg s "$sp" --arg l "$li" \
            '{status:"ready",path:"existing",workspaceId:$w,spaceId:$s,listId:$l}'
    else
        jq -nc --arg w "$ws" --arg s "$sp" --arg f "$fo" --arg n "$nl" \
            '{status:"ready",path:"create",workspaceId:$w,spaceId:$s,folderId:$f,newListName:$n}'
    fi
}

# ---- pin-list ----------------------------------------------------------------------------

cmd_pin_list() {
    $have_id || die "pin-list requires --id"
    [[ -n "$PIN_NAME" ]] || die "pin-list requires --name"
    local f="$COMMITTED"   # the committed layer resolve reads (legacy config.yml in grace mode)
    is_id "$PIN_ID" || { echo "pin-list: list-id \"$PIN_ID\" is not a ClickUp ID (IDs are numeric)" >&2; return 1; }
    local cur; cur="$(file_value "$f" list-id)"
    [[ -z "$cur" ]] || { echo "pin-list: $f already pins list-id \"$cur\" — not overwriting" >&2; return 1; }

    local line="list-id: \"$PIN_ID\"  # $PIN_NAME" tmp
    [[ -f "$f" ]] || : > "$f"
    tmp="$(mktemp "$f.XXXXXX")"
    if grep -q '^new-list-name:' "$f"; then
        PIN_LINE="$line" awk '!done && /^new-list-name:/ { print ENVIRON["PIN_LINE"]; done = 1; next } { print }' "$f" > "$tmp"
    else
        cat "$f" > "$tmp"
        [[ ! -s "$f" || -z "$(tail -c 1 "$f")" ]] || printf '\n' >> "$tmp"
        printf '%s\n' "$line" >> "$tmp"
    fi
    cat "$tmp" > "$f" && rm -f "$tmp"   # rewrite in place: the file keeps its mode
    echo "pinned list-id $PIN_ID ($PIN_NAME) in $f"
}

case "$SUB" in
    resolve)  cmd_resolve ;;
    pin-list) cmd_pin_list ;;
esac
