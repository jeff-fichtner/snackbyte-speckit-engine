#!/usr/bin/env bash
# release.sh — the one release action for snackbyte-speckit-engine (003 / contracts/release.command.md).
#
# Main entry (maintainer-run, local — user decision 2026-07-24):
#   release.sh <version> [--dry-run] [--port N]
#     Preflight → stamp lockstep version → check gate → build archives → leak scan →
#     generate catalog.json → commit + tag + push + `gh release create` with the assets.
#     --dry-run: side-effect-free — stamps a TEMP copy, builds dist/, emits
#     dist/catalog.json (GitHub URLs) + dist/catalog.local.json (http://localhost:<port>
#     URLs for the offline harness). Never touches the working tree.
#
# Deterministic subcommands (unit-tested in release.test.sh — Constitution V):
#   validate-version --version V              semver MAJOR.MINOR.PATCH, digits only
#   stamp --version V --root R                write V into every extensions/*/extension.yml + package.json
#   check-drift --root R                      all manifest versions + package.json equal, else name offenders
#   build --root R --out D                    one deterministic zip per extension (exclusions honored)
#   scan --dist D                             forbidden files/content in any archive → fail loud
#   catalog --root R --dist D --version V --base-url U --out F
#
# Repeatable builds: staged copies get a fixed mtime and sorted file order, so identical
# inputs yield byte-identical archives (US1 scenario 4).
set -euo pipefail

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_ROOT="$(cd -- "$SCRIPT_DIR/../../.." && pwd)"
FIXED_TS="200101010000"   # deterministic mtime for staged files
REPO_SLUG="jeff-fichtner/snackbyte-speckit-engine"

# Names that must never ship, and content that must never leak (this repo's real ClickUp ids).
FORBIDDEN_NAMES=(config.local.yml local-config.yml clickup-config.yml)
FORBIDDEN_CONTENT=(90141363864 90146433590 901417991049)

die() { echo "ERROR: $*" >&2; exit 1; }

sed_i() { # portable in-place sed (BSD/macOS `sed -i ''` vs GNU `sed -i`)
    local expr="$1" file="$2" tmp
    tmp="$(mktemp)"; sed "$expr" "$file" > "$tmp" && cat "$tmp" > "$file" && rm -f "$tmp"
}

sha256() {
    if command -v shasum >/dev/null 2>&1; then shasum -a 256 "$1" | cut -d' ' -f1
    else sha256sum "$1" | cut -d' ' -f1; fi
}

ext_dirs() { # $1=root — print extension dirs (sorted)
    find "$1/.specify/extensions" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | sort
}

manifest_field() { # $1=extension.yml $2=field — first "  field: value" inside the extension block
    sed -n "s/^  $2: *\"\{0,1\}\([^\"]*\)\"\{0,1\}\$/\1/p" "$1" | head -1
}

cmd_validate_version() {
    local version=""
    while [[ $# -gt 0 ]]; do case "$1" in --version) version="$2"; shift 2 ;; *) shift ;; esac; done
    [[ "$version" =~ ^(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)$ ]] \
        || die "not a plain MAJOR.MINOR.PATCH version: '$version'"
    echo "$version"
}

cmd_stamp() {
    local version="" root="$DEFAULT_ROOT"
    while [[ $# -gt 0 ]]; do case "$1" in --version) version="$2"; shift 2 ;; --root) root="$2"; shift 2 ;; *) shift ;; esac; done
    [[ -n "$version" ]] || die "stamp requires --version"
    local d
    for d in $(ext_dirs "$root"); do
        [[ -f "$d/extension.yml" ]] || continue
        sed_i "s/^  version: \".*\"$/  version: \"$version\"/" "$d/extension.yml"
    done
    [[ -f "$root/package.json" ]] && sed_i "s/\"version\": \".*\"/\"version\": \"$version\"/" "$root/package.json"
    echo "stamped $version"
}

cmd_check_drift() {
    local root="$DEFAULT_ROOT"
    while [[ $# -gt 0 ]]; do case "$1" in --root) root="$2"; shift 2 ;; *) shift ;; esac; done
    local ref="" bad=() d v
    for d in $(ext_dirs "$root"); do
        [[ -f "$d/extension.yml" ]] || continue
        v="$(manifest_field "$d/extension.yml" version)"
        [[ -z "$ref" ]] && ref="$v"
        [[ "$v" == "$ref" ]] || bad+=("$(basename "$d")=$v")
    done
    if [[ -f "$root/package.json" ]]; then
        v="$(sed -n 's/.*"version": "\([^"]*\)".*/\1/p' "$root/package.json" | head -1)"
        [[ "$v" == "$ref" ]] || bad+=("package.json=$v")
    fi
    [[ ${#bad[@]} -eq 0 ]] || die "version drift from $ref: ${bad[*]}"
    echo "lockstep at $ref"
}

stage_extension() { # $1=ext-dir $2=stage-dir — copy honoring .extensionignore + built-in exclusions
    local src="$1" stage="$2"
    mkdir -p "$stage"
    local tar_ex=(--exclude .cache --exclude .backup --exclude .DS_Store)
    local n
    for n in "${FORBIDDEN_NAMES[@]}"; do tar_ex+=(--exclude "$n"); done
    if [[ -f "$src/.extensionignore" ]]; then
        while IFS= read -r line; do
            line="${line%%#*}"; line="$(echo "$line" | tr -d '[:space:]')"
            [[ -n "$line" ]] && tar_ex+=(--exclude "${line%/}")
        done < "$src/.extensionignore"
    fi
    (cd "$src" && tar cf - "${tar_ex[@]}" .) | (cd "$stage" && tar xf -)
}

cmd_build() {
    local root="$DEFAULT_ROOT" out=""
    while [[ $# -gt 0 ]]; do case "$1" in --root) root="$2"; shift 2 ;; --out) out="$2"; shift 2 ;; *) shift ;; esac; done
    [[ -n "$out" ]] || die "build requires --out"
    mkdir -p "$out"
    local d id v stage zipfile
    for d in $(ext_dirs "$root"); do
        [[ -f "$d/extension.yml" ]] || continue
        id="$(manifest_field "$d/extension.yml" id)"
        v="$(manifest_field "$d/extension.yml" version)"
        [[ -n "$id" && -n "$v" ]] || die "cannot read id/version from $d/extension.yml"
        stage="$(mktemp -d)"
        stage_extension "$d" "$stage"
        find "$stage" -exec touch -t "$FIXED_TS" {} +
        zipfile="$out/$id-$v.zip"; rm -f "$zipfile"
        (cd "$stage" && find . -type f | sed 's|^\./||' | sort | TZ=UTC zip -X -q "$zipfile" -@)
        rm -rf "$stage"
        echo "built $(basename "$zipfile")"
    done
}

cmd_scan() {
    local dist=""
    while [[ $# -gt 0 ]]; do case "$1" in --dist) dist="$2"; shift 2 ;; *) shift ;; esac; done
    [[ -d "$dist" ]] || die "scan requires --dist <dir>"
    local z n hits tmp
    for z in "$dist"/*.zip; do
        [[ -f "$z" ]] || continue
        local listing; listing="$(unzip -l "$z")"
        for n in "${FORBIDDEN_NAMES[@]}"; do
            if echo "$listing" | grep -q "$n"; then die "forbidden file '$n' inside $(basename "$z")"; fi
        done
        tmp="$(mktemp -d)"; unzip -qq "$z" -d "$tmp"
        for n in "${FORBIDDEN_CONTENT[@]}"; do
            hits="$(grep -rl "$n" "$tmp" 2>/dev/null || true)"
            [[ -z "$hits" ]] || { rm -rf "$tmp"; die "forbidden content '$n' inside $(basename "$z")"; }
        done
        rm -rf "$tmp"
    done
    echo "scan clean"
}

cmd_catalog() {
    local root="$DEFAULT_ROOT" dist="" version="" base_url="" out=""
    while [[ $# -gt 0 ]]; do case "$1" in
        --root) root="$2"; shift 2 ;; --dist) dist="$2"; shift 2 ;;
        --version) version="$2"; shift 2 ;; --base-url) base_url="$2"; shift 2 ;;
        --out) out="$2"; shift 2 ;; *) shift ;; esac; done
    [[ -n "$dist" && -n "$version" && -n "$base_url" && -n "$out" ]] || die "catalog requires --dist --version --base-url --out"
    local entries="{}" d id v name desc zipfile sha
    for d in $(ext_dirs "$root"); do
        [[ -f "$d/extension.yml" ]] || continue
        id="$(manifest_field "$d/extension.yml" id)"
        v="$(manifest_field "$d/extension.yml" version)"
        name="$(manifest_field "$d/extension.yml" name)"
        desc="$(manifest_field "$d/extension.yml" description)"
        [[ "$v" == "$version" ]] || die "lockstep violation: $id declares $v, release is $version"
        zipfile="$dist/$id-$version.zip"
        [[ -f "$zipfile" ]] || die "missing archive for $id: $zipfile"
        sha="$(sha256 "$zipfile")"
        entries="$(jq --arg id "$id" --arg n "$name" --arg de "$desc" --arg ver "$version" \
            --arg u "$base_url/$id-$version.zip" --arg s "$sha" \
            '. + {($id): {name: $n, description: $de, version: $ver, download_url: $u, sha256: $s}}' <<< "$entries")"
    done
    jq -n --argjson e "$entries" '{schema_version: "1.0", extensions: $e}' > "$out"
    echo "catalog → $out"
}

preflight_publish() { # $1=version
    local version="$1" t
    for t in gh jq zip git; do command -v "$t" >/dev/null 2>&1 || die "required tool missing: $t"; done
    command -v shasum >/dev/null 2>&1 || command -v sha256sum >/dev/null 2>&1 || die "required tool missing: shasum/sha256sum"
    gh auth status >/dev/null 2>&1 || die "gh is not authenticated (run: gh auth login)"
    [[ -z "$(git -C "$DEFAULT_ROOT" status --porcelain)" ]] || die "working tree is dirty — commit or stash first"
    [[ "$(git -C "$DEFAULT_ROOT" branch --show-current)" == "main" ]] || die "releases are cut from main"
    local last; last="$(git -C "$DEFAULT_ROOT" tag -l 'v*' --sort=-v:refname | head -1)"
    if [[ -n "$last" ]]; then
        [[ "$(printf '%s\n%s\n' "${last#v}" "$version" | sort -V | tail -1)" == "$version" && "${last#v}" != "$version" ]] \
            || die "version $version is not greater than last tag $last"
    fi
    git -C "$DEFAULT_ROOT" rev-parse "v$version" >/dev/null 2>&1 && die "tag v$version already exists — roll forward with a new version"
    git -C "$DEFAULT_ROOT" ls-remote --tags origin "v$version" | grep -q . && die "tag v$version exists on origin — roll forward"
    return 0
}

main_release() {
    local version="$1"; shift
    local dry_run=false port=8931
    while [[ $# -gt 0 ]]; do case "$1" in --dry-run) dry_run=true; shift ;; --port) port="$2"; shift 2 ;; *) die "unknown flag: $1" ;; esac; done
    version="$(cmd_validate_version --version "$version")"

    if $dry_run; then
        for t in jq zip; do command -v "$t" >/dev/null 2>&1 || die "required tool missing: $t"; done
        local tmproot; tmproot="$(mktemp -d)"
        mkdir -p "$tmproot/.specify"
        cp -R "$DEFAULT_ROOT/.specify/extensions" "$tmproot/.specify/extensions"
        rm -rf "$tmproot/.specify/extensions/.cache" "$tmproot/.specify/extensions/.backup"
        cp "$DEFAULT_ROOT/package.json" "$tmproot/package.json"
        cmd_stamp --version "$version" --root "$tmproot" >/dev/null
        cmd_check_drift --root "$tmproot" >/dev/null
        (cd "$DEFAULT_ROOT" && npm run check:all --silent >/dev/null) || die "check gate is red — fix before releasing"
        local dist="$DEFAULT_ROOT/dist"; rm -rf "$dist"; mkdir -p "$dist"
        cmd_build --root "$tmproot" --out "$dist"
        cmd_scan --dist "$dist"
        cmd_catalog --root "$tmproot" --dist "$dist" --version "$version" \
            --base-url "https://github.com/$REPO_SLUG/releases/download/v$version" --out "$dist/catalog.json"
        cmd_catalog --root "$tmproot" --dist "$dist" --version "$version" \
            --base-url "http://localhost:$port/dist" --out "$dist/catalog.local.json"
        rm -rf "$tmproot"
        echo "DRY RUN complete: $(ls "$dist"/*.zip | wc -l | tr -d ' ') archives in dist/, catalog.json + catalog.local.json (port $port). Repo untouched."
        return 0
    fi

    preflight_publish "$version"
    cmd_stamp --version "$version" --root "$DEFAULT_ROOT"
    cmd_check_drift --root "$DEFAULT_ROOT"
    (cd "$DEFAULT_ROOT" && npm run check:all --silent >/dev/null) || die "check gate is red — fix before releasing"
    local dist="$DEFAULT_ROOT/dist"; rm -rf "$dist"; mkdir -p "$dist"
    cmd_build --root "$DEFAULT_ROOT" --out "$dist"
    cmd_scan --dist "$dist"
    cmd_catalog --root "$DEFAULT_ROOT" --dist "$dist" --version "$version" \
        --base-url "https://github.com/$REPO_SLUG/releases/download/v$version" --out "$DEFAULT_ROOT/catalog.json"
    git -C "$DEFAULT_ROOT" add -A
    git -C "$DEFAULT_ROOT" commit -m "release: v$version"
    git -C "$DEFAULT_ROOT" tag "v$version"
    git -C "$DEFAULT_ROOT" push origin HEAD "v$version"
    if gh release view "v$version" --repo "$REPO_SLUG" >/dev/null 2>&1; then
        die "release v$version already exists on GitHub"
    fi
    gh release create "v$version" --repo "$REPO_SLUG" --title "v$version" \
        --notes "snackbyte-speckit-engine v$version — install via the catalog (see docs/CONSUMING.md). Catalog updates may take up to 1h to reach consumers (CLI cache)." \
        "$dist"/*.zip
    echo "published v$version: $(ls "$dist"/*.zip | wc -l | tr -d ' ') assets + catalog.json committed"
}

sub="${1:-}"
case "$sub" in
    validate-version|stamp|check-drift|build|scan|catalog)
        cmd="${sub//-/_}"; shift; "cmd_$cmd" "$@" ;;
    "") die "usage: release.sh <version> [--dry-run] | <subcommand> ...  (see header)" ;;
    *)  main_release "$@" ;;
esac
