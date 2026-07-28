#!/usr/bin/env bash
# Tests for release.sh — the deterministic release functions (Constitution V / 003 FR-005).
# Orchestration (git/gh/network) is quickstart-validated, not unit-tested here.
# Run: bash .specify/scripts/bash/release.test.sh
set -uo pipefail

DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REL="$DIR/release.sh"
FAIL_F="$(mktemp)"
ok()  { printf '  ok   %s\n' "$1"; }
bad() { echo x >> "$FAIL_F"; printf '  FAIL %s — got %s\n' "$1" "$2"; }

TMP="$(mktemp -d)"; trap 'rm -rf "$TMP"' EXIT

# ---- fixture: a mini repo root with two extensions + package.json ----
mk_fixture() {
    local root="$1"
    mkdir -p "$root/.specify/extensions/alpha/commands" "$root/.specify/extensions/beta/scripts/bash"
    cat > "$root/.specify/extensions/alpha/extension.yml" <<'EOF'
schema_version: "1.0"

extension:
  id: alpha
  name: "Alpha"
  version: "1.0.0"
  description: "First fixture extension"
  author: test
  license: MIT

requires:
  speckit_version: ">=0.13.0"

provides:
  commands:
    - name: speckit.alpha.run
      file: commands/run.md
      description: "run"
EOF
    echo "# run" > "$root/.specify/extensions/alpha/commands/run.md"
    printf 'config.local.yml\nlocal-config.yml\nalpha-config.yml\n.cache/\n' > "$root/.specify/extensions/alpha/.extensionignore"
    echo 'space: "REAL VALUES"' > "$root/.specify/extensions/alpha/config.local.yml"
    mkdir -p "$root/.specify/extensions/alpha/.cache"; echo junk > "$root/.specify/extensions/alpha/.cache/x"
    cat > "$root/.specify/extensions/beta/extension.yml" <<'EOF'
schema_version: "1.0"

extension:
  id: beta
  name: "Beta"
  version: "1.0.0"
  description: "Second fixture extension"
  author: test
  license: MIT

requires:
  speckit_version: ">=0.13.0"

provides:
  commands:
    - name: speckit.beta.run
      file: commands/run.md
      description: "run"
EOF
    mkdir -p "$root/.specify/extensions/beta/commands"; echo "# run" > "$root/.specify/extensions/beta/commands/run.md"
    echo helper > "$root/.specify/extensions/beta/scripts/bash/h.sh"
    printf '{\n  "name": "fixture",\n  "version": "1.0.0",\n  "private": true\n}\n' > "$root/package.json"
}

R1="$TMP/r1"; mk_fixture "$R1"

# 1. semver validation
if bash "$REL" validate-version --version "1.2.3" >/dev/null 2>&1; then ok "semver 1.2.3 accepted"; else bad "semver-accept" "nonzero"; fi
for v in "1.2" "v1.2.3" "1.2.3-rc1" "abc"; do
    if bash "$REL" validate-version --version "$v" >/dev/null 2>&1; then bad "semver '$v' should fail" "exit0"; else ok "semver '$v' rejected"; fi
done

# 2. stamp + drift
bash "$REL" stamp --version "2.5.0" --root "$R1" >/dev/null 2>&1
n="$(grep -l 'version: "2.5.0"' "$R1"/.specify/extensions/*/extension.yml | wc -l | tr -d ' ')"
[[ "$n" == "2" ]] && ok "stamp writes both manifests" || bad "stamp-manifests" "$n"
grep -q '"version": "2.5.0"' "$R1/package.json" && ok "stamp writes package.json" || bad "stamp-pkg" "unchanged"
bash "$REL" check-drift --root "$R1" >/dev/null 2>&1 && ok "no drift after stamp" || bad "drift-clean" "nonzero"
sed -i '' 's/version: "2.5.0"/version: "9.9.9"/' "$R1/.specify/extensions/beta/extension.yml"
out="$(bash "$REL" check-drift --root "$R1" 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *beta* ]]; then ok "drift detected, names beta"; else bad "drift-detect" "rc=$rc out=$out"; fi
sed -i '' 's/version: "9.9.9"/version: "2.5.0"/' "$R1/.specify/extensions/beta/extension.yml"

# 3. build: exclusions + layout + repeatability
D1="$TMP/dist1"; bash "$REL" build --root "$R1" --out "$D1" >/dev/null 2>&1
[[ -f "$D1/alpha-2.5.0.zip" && -f "$D1/beta-2.5.0.zip" ]] && ok "build produces one zip per extension" || bad "build-zips" "$(ls "$D1" 2>/dev/null)"
lst="$(unzip -l "$D1/alpha-2.5.0.zip")"
[[ "$lst" == *"extension.yml"* ]] && ok "extension.yml at archive root" || bad "zip-root" "$lst"
if [[ "$lst" == *"config.local.yml"* || "$lst" == *".cache"* ]]; then bad "exclusions honored" "leaked"; else ok "local config + cache excluded"; fi
[[ "$lst" == *".extensionignore"* ]] && ok ".extensionignore ships" || bad "ignore-ships" "missing"
D2="$TMP/dist2"; bash "$REL" build --root "$R1" --out "$D2" >/dev/null 2>&1
cmp -s "$D1/alpha-2.5.0.zip" "$D2/alpha-2.5.0.zip" && ok "rebuild is byte-identical" || bad "repeatable" "differs"

# 4. scan: clean passes; planted forbidden file fails; forbidden content fails
bash "$REL" scan --dist "$D1" >/dev/null 2>&1 && ok "clean dist passes scan" || bad "scan-clean" "nonzero"
DBAD="$TMP/distbad"; mkdir -p "$DBAD/stage"; cp -r "$R1/.specify/extensions/alpha/." "$DBAD/stage/"
( cd "$DBAD/stage" && zip -q -r "$DBAD/alpha-2.5.0.zip" . )
out="$(bash "$REL" scan --dist "$DBAD" 2>&1)"; rc=$?
if [[ $rc -ne 0 && "$out" == *config.local.yml* ]]; then ok "planted local config fails scan"; else bad "scan-file" "rc=$rc"; fi
DBAD2="$TMP/distbad2"; mkdir -p "$DBAD2/stage/commands"
cp "$R1/.specify/extensions/beta/extension.yml" "$DBAD2/stage/extension.yml"
echo "workspace 90141363864" > "$DBAD2/stage/commands/leak.md"
( cd "$DBAD2/stage" && zip -q -r "$DBAD2/beta-2.5.0.zip" . )
if bash "$REL" scan --dist "$DBAD2" >/dev/null 2>&1; then bad "planted workspace id should fail scan" "exit0"; else ok "planted workspace id fails scan"; fi

# 5. catalog: schema + lockstep + determinism
C1="$TMP/cat1.json"
bash "$REL" catalog --root "$R1" --dist "$D1" --version "2.5.0" --base-url "https://example.com/rel" --out "$C1" >/dev/null 2>&1
jq -e '.schema_version and (.extensions | type == "object")' "$C1" >/dev/null && ok "catalog has schema_version + extensions object" || bad "cat-schema" "$(cat "$C1")"
jq -e '.extensions.alpha.version == "2.5.0" and .extensions.beta.version == "2.5.0"' "$C1" >/dev/null && ok "catalog versions lockstep" || bad "cat-ver" "$(cat "$C1")"
jq -e '.extensions.alpha.download_url == "https://example.com/rel/alpha-2.5.0.zip"' "$C1" >/dev/null && ok "download_url composed" || bad "cat-url" "$(cat "$C1")"
want="$(shasum -a 256 "$D1/alpha-2.5.0.zip" | cut -d' ' -f1)"
[[ "$(jq -r '.extensions.alpha.sha256' "$C1")" == "$want" ]] && ok "sha256 matches archive" || bad "cat-sha" "mismatch"
C2="$TMP/cat2.json"
bash "$REL" catalog --root "$R1" --dist "$D1" --version "2.5.0" --base-url "https://example.com/rel" --out "$C2" >/dev/null 2>&1
cmp -s "$C1" "$C2" && ok "catalog generation byte-stable" || bad "cat-stable" "differs"
sed -i '' 's/version: "2.5.0"/version: "3.0.0"/' "$R1/.specify/extensions/beta/extension.yml"
if bash "$REL" catalog --root "$R1" --dist "$D1" --version "2.5.0" --base-url "u" --out "$TMP/cat3.json" >/dev/null 2>&1; then
    bad "catalog should fail on lockstep drift" "exit0"; else ok "catalog fails on lockstep drift"; fi

n="$(wc -l < "$FAIL_F" | tr -d '[:space:]')"; n="${n:-0}"
echo ""
if [[ "$n" -eq 0 ]]; then echo "release: ALL PASS"; else echo "release: $n FAIL"; exit 1; fi
