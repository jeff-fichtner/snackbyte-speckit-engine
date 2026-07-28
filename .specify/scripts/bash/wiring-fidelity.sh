#!/usr/bin/env bash
# wiring-fidelity.sh — verify a repo's extensions.yml hook wiring matches the extension
# manifests, field for field (003 US5 / SC-004 / FR-014).
#
# The installer copies each manifest hook entry (command, optional, priority, prompt,
# description) verbatim into the consumer's extensions.yml. This script normalizes BOTH sides
# into canonical "event|extension|command|optional|priority|prompt|description" lines and
# diffs the sets. Defaults mirror the installer: priority 10, prompt "Execute <command>?",
# description "".
#
# Usage: wiring-fidelity.sh --wiring <extensions.yml> --extensions-dir <dir> [--only-installed]
#   --only-installed  compare only manifests whose id appears in the wiring (skip extras)
# Exit 0 = fidelity; non-zero = drift, printed as unified diff (manifest-expected vs wired).
set -euo pipefail

WIRING="" EXT_DIR="" ONLY_INSTALLED=false
while [[ $# -gt 0 ]]; do case "$1" in
    --wiring) WIRING="$2"; shift 2 ;;
    --extensions-dir) EXT_DIR="$2"; shift 2 ;;
    --only-installed) ONLY_INSTALLED=true; shift ;;
    --help|-h) sed -n '2,15p' "$0"; exit 0 ;;
    *) echo "ERROR: unknown arg $1" >&2; exit 2 ;;
esac; done
[[ -f "$WIRING" && -d "$EXT_DIR" ]] || { echo "ERROR: need --wiring <file> and --extensions-dir <dir>" >&2; exit 2; }

strip() { # trim + strip surrounding quotes
    local s="$1"; s="${s#"${s%%[![:space:]]*}"}"; s="${s%"${s##*[![:space:]]}"}"
    s="${s#\"}"; s="${s%\"}"; printf '%s' "$s"
}

# ---- normalize one manifest's hooks → canonical lines ----
manifest_lines() { # $1=extension.yml $2=ext-id
    awk -v id="$2" '
    function unq(s) { gsub(/^['"'"'"]|['"'"'"]$/, "", s); gsub(/'"''"'/, "'"'"'", s); return s }
    function flush() {
        if (cmd != "") {
            if (pri == "") pri = 10
            prompt = unq(prompt); desc = unq(desc)
            if (prompt == "") prompt = "Execute " cmd "?"
            printf "%s|%s|%s|%s|%s|%s|%s\n", ev, id, cmd, opt, pri, prompt, desc
        }
        cmd=""; opt=""; pri=""; prompt=""; desc=""; last=""
    }
    /^hooks:/ { inh=1; next }
    inh && /^[a-z_]+:/ && !/^  / { inh=0 }   # left hooks block (tags:, etc.)
    !inh { next }
    /^  [a-z_]+:$/            { flush(); ev=$1; sub(/:$/, "", ev); sub(/^ +/, "", ev); next }
    /^    - command:|^    command:/ { flush_keep_ev(); v=$0; sub(/^.*command: */, "", v); cmd=v; next }
    /^ +optional:/            { v=$0; sub(/^.*optional: */, "", v); opt=v; next }
    /^ +priority:/            { v=$0; sub(/^.*priority: */, "", v); pri=v; next }
    /^ +prompt:/              { v=$0; sub(/^ +prompt: */, "", v); prompt=v; last="prompt"; next }
    /^ +description:/         { v=$0; sub(/^ +description: */, "", v); desc=v; last="desc"; next }
    /^ +[^ :]+$/ || (/^ +/ && $0 !~ /: /) {   # continuation of a wrapped scalar
        v=$0; sub(/^ +/, "", v)
        if (last=="prompt") prompt=prompt " " v
        else if (last=="desc") desc=desc " " v
        next }
    function flush_keep_ev(  e) { e=ev; flush(); ev=e }
    END { flush() }
    ' "$1"
}

# ---- normalize extensions.yml hooks → canonical lines ----
wiring_lines() { # $1=extensions.yml
    awk '
    /^hooks:/ { inh=1; next }
    inh && /^[a-z_]+:/ && !/^  / { inh=0 }
    !inh { next }
    function unq(s) { gsub(/^['"'"'"]|['"'"'"]$/, "", s); gsub(/'"''"'/, "'"'"'", s); return s }
    function flush() {
        if (cmd != "") {
            if (pri == "") pri = 10
            prompt = unq(prompt); desc = unq(desc)
            if (prompt == "") prompt = "Execute " cmd "?"
            printf "%s|%s|%s|%s|%s|%s|%s\n", ev, ext, cmd, opt, pri, prompt, desc
        }
        ext=""; cmd=""; opt=""; pri=""; prompt=""; desc=""; last=""
    }
    /^  [a-z_]+:$/       { flush(); ev=$1; sub(/:$/, "", ev); sub(/^ +/, "", ev); next }
    /^  - extension:/    { flush_keep_ev(); v=$0; sub(/^.*extension: */, "", v); ext=v; next }
    /^    command:/      { v=$0; sub(/^.*command: */, "", v); cmd=v; next }
    /^    optional:/     { v=$0; sub(/^.*optional: */, "", v); opt=v; next }
    /^    priority:/     { v=$0; sub(/^.*priority: */, "", v); pri=v; next }
    /^    prompt:/       { v=$0; sub(/^    prompt: */, "", v); prompt=v; last="prompt"; next }
    /^    description:/  { v=$0; sub(/^    description: */, "", v); desc=v; last="desc"; next }
    /^      / && $0 !~ /: / {                 # continuation of a wrapped scalar
        v=$0; sub(/^ +/, "", v)
        if (last=="prompt") prompt=prompt " " v
        else if (last=="desc") desc=desc " " v
        next }
    function flush_keep_ev(  e) { e=ev; flush(); ev=e }
    END { flush() }
    ' "$1"
}

EXPECTED="$(mktemp)"; ACTUAL="$(mktemp)"; DIFF_F="$(mktemp)"; trap 'rm -f "$EXPECTED" "$ACTUAL" "$DIFF_F"' EXIT

for d in "$EXT_DIR"/*/; do
    [[ -f "$d/extension.yml" ]] || continue
    id="$(sed -n 's/^  id: *\(.*\)$/\1/p' "$d/extension.yml" | head -1)"
    if $ONLY_INSTALLED && ! grep -q "extension: $id\$" "$WIRING"; then continue; fi
    manifest_lines "$d/extension.yml" "$id"
done | sort > "$EXPECTED"

wiring_lines "$WIRING" | sort > "$ACTUAL"

if diff -u "$EXPECTED" "$ACTUAL" > "$DIFF_F" 2>&1; then
    echo "fidelity OK: $(wc -l < "$EXPECTED" | tr -d ' ') hook entries match field-for-field"
else
    echo "FIDELITY DRIFT (expected-from-manifests vs wired):" >&2
    cat "$DIFF_F" >&2
    exit 1
fi
