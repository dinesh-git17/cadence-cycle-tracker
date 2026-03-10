#!/usr/bin/env bash
# setup-hooks.sh
# One-command bootstrap for Cadence git hook governance.
#
# Installs pre-commit hooks for all three stages:
#   pre-commit  -- lint, scan, format checks on staged files
#   commit-msg  -- Conventional Commits + Protocol Zero on message text
#   pre-push    -- block direct pushes to main
#
# Usage:
#   ./scripts/setup-hooks.sh           Install hooks
#   ./scripts/setup-hooks.sh --check   Verify installation without modifying
#
# Prerequisites:
#   brew install pre-commit swiftlint swiftformat

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

REPO_ROOT="$(git rev-parse --show-toplevel 2>/dev/null || true)"

if [[ -z "$REPO_ROOT" ]]; then
    printf '%s%s[FAIL]%s  Not inside a git repository.\n' "$RED" "$BOLD" "$NC"
    exit 1
fi

cd "$REPO_ROOT"

printf '\n'
printf '%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════'
printf '%s  Cadence  --  Git Hook Setup%s\n' "$BOLD" "$NC"
printf '%s%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════' "$NC"
printf '\n'

# ── Dependency check ─────────────────────────────────────────────────────
printf '%s%s─── Prerequisites %s\n\n' "$CYAN" "$BOLD" "$NC"

missing=()

for cmd in pre-commit swiftlint swiftformat git; do
    if command -v "$cmd" > /dev/null 2>&1; then
        version=$("$cmd" --version 2>/dev/null | head -1)
        printf '  %s%s[OK]%s    %-16s %s%s%s\n' "$GREEN" "$BOLD" "$NC" "$cmd" "$DIM" "$version" "$NC"
    else
        printf '  %s%s[MISS]%s  %-16s %snot found%s\n' "$RED" "$BOLD" "$NC" "$cmd" "$DIM" "$NC"
        missing+=("$cmd")
    fi
done

printf '\n'

if [[ ${#missing[@]} -gt 0 ]]; then
    printf '  %s%s[FAIL]%s  Missing dependencies: %s\n' "$RED" "$BOLD" "$NC" "${missing[*]}"
    printf '         Install with: brew install %s\n\n' "${missing[*]}"
    exit 1
fi

if [[ "${1:-}" == "--check" ]]; then
    printf '%s%s─── Hook Status %s\n\n' "$CYAN" "$BOLD" "$NC"

    for stage in pre-commit commit-msg pre-push; do
        hook_file="$REPO_ROOT/.git/hooks/$stage"
        if [[ -f "$hook_file" ]] && grep -q 'pre-commit' "$hook_file" 2>/dev/null; then
            printf '  %s%s[OK]%s    %s\n' "$GREEN" "$BOLD" "$NC" "$stage"
        else
            printf '  %s%s[MISS]%s  %s\n' "$YELLOW" "$BOLD" "$NC" "$stage"
        fi
    done

    printf '\n'
    exit 0
fi

# ── Install hooks ────────────────────────────────────────────────────────
printf '%s%s─── Installing Hooks %s\n\n' "$CYAN" "$BOLD" "$NC"

pre-commit install --install-hooks 2>&1 | sed 's/^/  /'
pre-commit install --hook-type commit-msg 2>&1 | sed 's/^/  /'
pre-commit install --hook-type pre-push 2>&1 | sed 's/^/  /'

printf '\n'

# ── Verification ─────────────────────────────────────────────────────────
printf '%s%s─── Verification %s\n\n' "$CYAN" "$BOLD" "$NC"

all_installed=true
for stage in pre-commit commit-msg pre-push; do
    hook_file="$REPO_ROOT/.git/hooks/$stage"
    if [[ -f "$hook_file" ]] && grep -q 'pre-commit' "$hook_file" 2>/dev/null; then
        printf '  %s%s[OK]%s    %s hook installed\n' "$GREEN" "$BOLD" "$NC" "$stage"
    else
        printf '  %s%s[FAIL]%s  %s hook missing\n' "$RED" "$BOLD" "$NC" "$stage"
        all_installed=false
    fi
done

printf '\n'

if [[ "$all_installed" == true ]]; then
    printf '  %s%-24s%s %s%sPASS%s\n' "$BOLD" "Result:" "$NC" "$GREEN" "$BOLD" "$NC"
    printf '\n'
    printf '  %sAll hooks active. Commits and pushes are now governed.%s\n' "$DIM" "$NC"
    printf '  %sRun: pre-commit run --all-files   to scan the full codebase.%s\n' "$DIM" "$NC"
else
    printf '  %s%-24s%s %s%sFAIL%s\n' "$BOLD" "Result:" "$NC" "$RED" "$BOLD" "$NC"
    printf '\n'
    printf '  %sSome hooks failed to install. Check output above.%s\n' "$DIM" "$NC"
fi

printf '\n'
