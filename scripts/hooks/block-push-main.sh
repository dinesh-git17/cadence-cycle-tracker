#!/usr/bin/env bash
# block-push-main.sh
# Pre-push hook -- blocks direct pushes to main branch.
# All changes must reach main through a pull request.
#
# Pre-push hooks receive lines on stdin:
#   <local ref> <local sha> <remote ref> <remote sha>
#
# Exit codes:
#   0  Push allowed
#   1  Push to main blocked

set -euo pipefail

RED=$'\033[0;31m'
YELLOW=$'\033[0;33m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

if ! [ -t 1 ]; then
    RED="" YELLOW="" BOLD="" DIM="" NC=""
fi

blocked=false

while IFS=' ' read -r local_ref local_sha remote_ref remote_sha; do
    if [[ "$remote_ref" == "refs/heads/main" || "$remote_ref" == "refs/heads/master" ]]; then
        blocked=true
        break
    fi
done

if [[ "$blocked" == true ]]; then
    printf '\n'
    printf '%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════'
    printf '%s  Cadence  --  Branch Protection  [pre-push]%s\n' "$BOLD" "$NC"
    printf '%s%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════' "$NC"
    printf '\n'

    printf '  %s%s[FAIL]%s  Direct push to main is prohibited.\n\n' "$RED" "$BOLD" "$NC"
    printf '  All changes must reach main through a pull request.\n'
    printf '  See CLAUDE.md S6 / S7.1.\n'
    printf '\n'

    printf '  %s%sTo fix:%s\n' "$YELLOW" "$BOLD" "$NC"
    printf '    git checkout -b feat/<description>\n'
    printf '    git push -u origin feat/<description>\n'
    printf '    gh pr create\n'
    printf '\n'
    printf '  %sOverride (emergency only): git push --no-verify%s\n' "$DIM" "$NC"
    printf '\n'

    exit 1
fi

exit 0
