#!/usr/bin/env bash
# Tests for wiring-fidelity.sh (003 US5 / SC-004). Run: bash .specify/scripts/bash/wiring-fidelity.test.sh
set -uo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
WF="$DIR/wiring-fidelity.sh"
FAIL_F="$(mktemp)"
ok()  { printf '  ok   %s\n' "$1"; }
bad() { echo x >> "$FAIL_F"; printf '  FAIL %s — got %s\n' "$1" "$2"; }
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/ext/alpha"
cat > "$TMP/ext/alpha/extension.yml" <<'EOF'
schema_version: "1.0"

extension:
  id: alpha
  name: "Alpha"
  version: "1.0.0"
  description: "fixture"
  author: t
  license: MIT

requires:
  speckit_version: ">=0.13.0"

provides:
  commands:
    - name: speckit.alpha.run
      file: commands/run.md
      description: "run"

hooks:
  after_specify:
    - command: speckit.alpha.run
      optional: false
      priority: 5
      prompt: "Run alpha first?"
      description: "first entry"
    - command: speckit.alpha.run
      optional: false
      priority: 15
      prompt: "Run alpha again?"
      description: "second entry"
  after_tasks:
    command: speckit.alpha.run
    optional: false
    priority: 10
    prompt: "Alpha after tasks?"
    description: "single entry"

tags:
  - "t"
EOF

cat > "$TMP/wiring.yml" <<'EOF'
installed:
- alpha
settings:
  auto_execute_hooks: true
hooks:
  after_specify:
  - extension: alpha
    command: speckit.alpha.run
    enabled: true
    optional: false
    priority: 5
    prompt: Run alpha first?
    description: first entry
    condition: null
  - extension: alpha
    command: speckit.alpha.run
    enabled: true
    optional: false
    priority: 15
    prompt: Run alpha again?
    description: second entry
    condition: null
  after_tasks:
  - extension: alpha
    command: speckit.alpha.run
    enabled: true
    optional: false
    priority: 10
    prompt: Alpha after tasks?
    description: single entry
    condition: null
EOF

# 1. matching pair → fidelity OK
bash "$WF" --wiring "$TMP/wiring.yml" --extensions-dir "$TMP/ext" >/dev/null 2>&1 \
    && ok "matching wiring passes" || bad "match" "nonzero"

# 2. mutated prompt → drift, names the prompt
sed 's/Run alpha again?/Run alpha AGAIN?/' "$TMP/wiring.yml" > "$TMP/wiring2.yml"
out="$(bash "$WF" --wiring "$TMP/wiring2.yml" --extensions-dir "$TMP/ext" 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *AGAIN* ]]; then ok "mutated prompt detected"; else bad "prompt-drift" "rc=$rc"; fi

# 3. mutated priority → drift
sed 's/priority: 15/priority: 12/' "$TMP/wiring.yml" > "$TMP/wiring3.yml"
if bash "$WF" --wiring "$TMP/wiring3.yml" --extensions-dir "$TMP/ext" >/dev/null 2>&1; then
    bad "priority drift should fail" "exit0"; else ok "mutated priority detected"; fi

# 4. missing entry → drift
grep -v 'Alpha after tasks?' "$TMP/wiring.yml" | sed '/after_tasks:/,$d' > "$TMP/wiring4.yml"
if bash "$WF" --wiring "$TMP/wiring4.yml" --extensions-dir "$TMP/ext" >/dev/null 2>&1; then
    bad "missing entry should fail" "exit0"; else ok "missing entry detected"; fi

n="$(wc -l < "$FAIL_F" | tr -d '[:space:]')"; n="${n:-0}"
echo ""
if [[ "$n" -eq 0 ]]; then echo "wiring-fidelity: ALL PASS"; else echo "wiring-fidelity: $n FAIL"; exit 1; fi
