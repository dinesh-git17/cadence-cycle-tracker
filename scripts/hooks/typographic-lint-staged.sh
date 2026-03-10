#!/usr/bin/env bash
# typographic-lint-staged.sh
# Pre-commit wrapper -- runs Typographic Lint on staged files only.
# Delegates to scripts/check-em-dashes.sh with a temp directory of staged content.
#
# Exit codes:
#   0  Clean
#   1  Violation(s) detected

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$REPO_ROOT/scripts/check-em-dashes.sh"

if [[ ! -x "$SCRIPT" ]]; then
    printf 'typographic-lint-staged: cannot find %s\n' "$SCRIPT" >&2
    exit 1
fi

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR)

if [[ -z "$STAGED_FILES" ]]; then
    exit 0
fi

HARD_EXEMPT_DIRS=("docs/" ".claude/")
HARD_EXEMPT_FILES=("CLAUDE.md" "protocol-zero.sh" "check-em-dashes.sh" "settings.local.json" "MEMORY.md")
SKIP_EXTENSIONS=("png" "jpg" "jpeg" "gif" "ico" "svg" "webp" "woff" "woff2" "ttf" "otf" "pdf" "zip" "tar" "gz" "mp3" "mp4" "wav" "m4a" "aac" "ipa" "car" "mobileprovision" "db" "lock" "lockb" "p8" "skill" "xcframework" "md")

has_scannable_files=false
while IFS= read -r file; do
    skip=false
    for exempt_dir in "${HARD_EXEMPT_DIRS[@]}"; do
        if [[ "$file" == "$exempt_dir"* ]]; then
            skip=true
            break
        fi
    done
    if [[ "$skip" == true ]]; then
        continue
    fi
    basename_file=$(basename "$file")
    for exempt_file in "${HARD_EXEMPT_FILES[@]}"; do
        if [[ "$basename_file" == "$exempt_file" ]]; then
            skip=true
            break
        fi
    done
    if [[ "$skip" == true ]]; then
        continue
    fi
    ext="${file##*.}"
    for skip_ext in "${SKIP_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$skip_ext" ]]; then
            skip=true
            break
        fi
    done
    if [[ "$skip" == true ]]; then
        continue
    fi
    has_scannable_files=true
    break
done <<< "$STAGED_FILES"

if [[ "$has_scannable_files" == false ]]; then
    exit 0
fi

TMPDIR_STAGED=$(mktemp -d)
trap 'rm -rf "$TMPDIR_STAGED"' EXIT

while IFS= read -r file; do
    if [[ ! -f "$REPO_ROOT/$file" ]]; then
        continue
    fi
    target_dir="$TMPDIR_STAGED/$(dirname "$file")"
    mkdir -p "$target_dir"
    cp "$REPO_ROOT/$file" "$target_dir/"
done <<< "$STAGED_FILES"

"$SCRIPT" --dir "$TMPDIR_STAGED"
