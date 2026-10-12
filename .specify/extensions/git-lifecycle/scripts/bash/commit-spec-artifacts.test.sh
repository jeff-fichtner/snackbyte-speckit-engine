#!/usr/bin/env bash
# Tests for commit-spec-artifacts.sh — the pre-implement checkpoint commits the feature's spec dir
# plus repo-level extension config changed during the lifecycle (e.g. a list ID pinned by
# provision), and nothing else (006 US3 / FR-009).
# Run: bash .specify/extensions/git-lifecycle/scripts/bash/commit-spec-artifacts.test.sh
set -uo pipefail
DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REAL_ROOT="$(cd -- "$DIR/../../../../.." && pwd)"
FAIL_F="$(mktemp)"
TMP="$(mktemp -d)"; trap 'rm -rf "$TMP" "$FAIL_F"' EXIT
ok()  { printf '  ok   %s\n' "$1"; }
bad() { echo x >> "$FAIL_F"; printf '  FAIL %s — got %s\n' "$1" "$2"; }

R="$TMP/repo"
mkdir -p "$R/.specify/scripts/bash" "$R/.specify/extensions/git-lifecycle/scripts/bash" \
         "$R/.specify/extensions/clickup" "$R/.specify/extensions/other" "$R/specs/001-x" "$R/src"
cp "$REAL_ROOT/.specify/scripts/bash/common.sh" "$R/.specify/scripts/bash/"
cp "$DIR/commit-spec-artifacts.sh" "$R/.specify/extensions/git-lifecycle/scripts/bash/"
printf '{\n  "feature_directory": "specs/001-x"\n}\n' > "$R/.specify/feature.json"
printf '.specify/extensions/*/local-config.yml\n' > "$R/.gitignore"
printf 'workspace-id: "1"\nnew-list-name: "Roadmap"\n' > "$R/.specify/extensions/clickup/clickup-config.yml"
printf 'x: 1\n' > "$R/.specify/extensions/other/other-config.yml"
printf 'code\n' > "$R/src/app.txt"
git -C "$R" init -q && git -C "$R" config user.email t@t && git -C "$R" config user.name t
git -C "$R" add -A && git -C "$R" commit -qm init

# The lifecycle since before_specify: spec written, provision pinned the list, plus unrelated noise.
printf '# spec\n' > "$R/specs/001-x/spec.md"
printf 'workspace-id: "1"\nlist-id: "777"  # Roadmap\n' > "$R/.specify/extensions/clickup/clickup-config.yml"
printf 'local: secret\n' > "$R/.specify/extensions/clickup/local-config.yml"
mkdir -p "$R/.specify/extensions/new" && printf 'y: 2\n' > "$R/.specify/extensions/new/new-config.yml"
printf 'changed\n' > "$R/src/app.txt"
printf 'not config\n' > "$R/.specify/extensions/clickup/notes.yml"

out="$(cd "$R" && bash .specify/extensions/git-lifecycle/scripts/bash/commit-spec-artifacts.sh --json)"; rc=$?
[[ $rc == 0 ]] && [[ "$(jq -r .status <<<"$out")" == "committed" ]] && ok "checkpoint commits" || bad "commit" "$rc $out"

files="$(git -C "$R" show --name-only --format= HEAD | sort)"
want=$'.specify/extensions/clickup/clickup-config.yml\n.specify/extensions/new/new-config.yml\nspecs/001-x/spec.md'
[[ "$files" == "$want" ]] && ok "commit = spec dir + changed/untracked extension *-config.yml" || bad "files" "$files"
grep -q 'local-config.yml' <<<"$files" && bad "local excluded" "$files" || ok "local-config.yml (gitignored) not committed"
st="$(git -C "$R" status --porcelain | sort)"
grep -q ' src/app.txt' <<<"$st" && grep -q 'notes.yml' <<<"$st" && ok "unrelated changes left in the working tree" || bad "unrelated" "$st"

out="$(cd "$R" && bash .specify/extensions/git-lifecycle/scripts/bash/commit-spec-artifacts.sh --json)"
[[ "$(jq -r .status <<<"$out")" == "nothing-to-commit" ]] && ok "re-run with nothing new → clean no-op" || bad "noop" "$out"

printf 'x: 2\n' > "$R/.specify/extensions/other/other-config.yml"
out="$(cd "$R" && bash .specify/extensions/git-lifecycle/scripts/bash/commit-spec-artifacts.sh --json)"
[[ "$(jq -r .status <<<"$out")" == "committed" && "$(git -C "$R" show --name-only --format= HEAD)" == ".specify/extensions/other/other-config.yml" ]] \
    && ok "a config-only change is checkpointed too" || bad "config-only" "$out"

f="$(wc -l < "$FAIL_F" | tr -d '[:space:]')"; f="${f:-0}"
if [[ "$f" -ne 0 ]]; then echo "commit-spec-artifacts.test.sh: $f FAILED"; exit 1; fi
echo "commit-spec-artifacts.test.sh: all passed"
