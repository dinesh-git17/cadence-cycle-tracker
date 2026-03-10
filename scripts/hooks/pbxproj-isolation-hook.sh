#!/usr/bin/env bash
# pbxproj-isolation-hook.sh
# Pre-commit hook -- rejects commits that stage .pbxproj alongside Swift source.
# .pbxproj regenerations must be isolated chore(project): commits per cadence-git.
#
# Exit codes:
#   0  Clean (no mixing detected)
#   1  Mixed staging detected

set -euo pipefail

RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

if ! [ -t 1 ]; then
    RED="" GREEN="" YELLOW="" CYAN="" BOLD="" DIM="" NC=""
fi

STAGED_FILES=$(git diff --cached --name-only --diff-filter=ACMR)

has_pbxproj=false
has_swift=false

while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    if [[ "$file" == *.pbxproj ]]; then
        has_pbxproj=true
    fi
    if [[ "$file" == *.swift ]]; then
        has_swift=true
    fi
done <<< "$STAGED_FILES"

if [[ "$has_pbxproj" == true && "$has_swift" == true ]]; then
    printf '\n'
    printf '%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════'
    printf '%s  Cadence  --  pbxproj Isolation Guard%s\n' "$BOLD" "$NC"
    printf '%s%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════' "$NC"
    printf '\n'

    printf '  %s%s[FAIL]%s  .pbxproj and .swift files are staged together.\n\n' "$RED" "$BOLD" "$NC"

    printf '  XcodeGen project regenerations must be isolated in their own commit\n'
    printf '  with type chore(project):. Never mix with Swift feature logic.\n'
    printf '\n'

    printf '  %s%sTo fix:%s\n' "$YELLOW" "$BOLD" "$NC"
    printf '    1. Unstage the .pbxproj:  git reset HEAD -- *.pbxproj\n'
    printf '    2. Commit Swift changes:  git commit -m "feat(scope): ..."\n'
    printf '    3. Stage and commit project separately:\n'
    printf '         git add Cadence.xcodeproj/project.pbxproj\n'
    printf '         git commit -m "chore(project): regenerate xcodeproj"\n'
    printf '\n'
    printf '  %sSee: cadence-git skill, CLAUDE.md S6%s\n' "$DIM" "$NC"
    printf '\n'

    exit 1
fi

exit 0
