#!/usr/bin/env bash
# no-hex-in-swift-hook.sh
# Pre-commit hook -- detects hardcoded hex color values in staged Swift files.
# Enforces CLAUDE.md S7: all colors must use Color("CadenceTokenName") from xcassets.
#
# Exit codes:
#   0  Clean
#   1  Violation(s) detected

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

VIOLATIONS=()

HEX_PATTERNS=(
    '#[0-9A-Fa-f]{6}\b'
    '#[0-9A-Fa-f]{8}\b'
    'Color\s*\(\s*red\s*:'
    'UIColor\s*\(\s*red\s*:'
    'Color\s*\(\s*\.sRGB'
    'UIColor\s*\(\s*displayP3Red\s*:'
)

for file in "$@"; do
    if [[ ! "$file" =~ \.swift$ ]]; then
        continue
    fi
    if [[ ! -f "$file" ]]; then
        continue
    fi

    for pattern in "${HEX_PATTERNS[@]}"; do
        matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
                line_num=$(printf '%s' "$match" | cut -d: -f1)
                content=$(printf '%s' "$match" | cut -d: -f2-)
                content="${content:0:60}"
                VIOLATIONS+=("${file}|${line_num}|${content}")
            done <<< "$matches"
        fi
    done
done

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
    exit 0
fi

printf '\n'
printf '%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════'
printf '%s  Cadence  --  No Hex Colors in Swift%s\n' "$BOLD" "$NC"
printf '%s%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════' "$NC"
printf '\n'

printf '%s%s─── Staged File Scan %s\n\n' "$CYAN" "$BOLD" "$NC"

COL_FILE=40
COL_LINE=5
COL_CONTENT=40

sep_file=$(printf '%0.s─' $(seq 1 "$COL_FILE"))
sep_line=$(printf '%0.s─' $(seq 1 "$COL_LINE"))
sep_content=$(printf '%0.s─' $(seq 1 "$COL_CONTENT"))

printf '  %s%-*s  %-*s  %-*s%s\n' \
    "$BOLD" \
    "$COL_FILE" "FILE" \
    "$COL_LINE" "LINE" \
    "$COL_CONTENT" "PATTERN" \
    "$NC"
printf '  %s%-*s  %-*s  %-*s%s\n' \
    "$DIM" \
    "$COL_FILE" "$sep_file" \
    "$COL_LINE" "$sep_line" \
    "$COL_CONTENT" "$sep_content" \
    "$NC"

for record in "${VIOLATIONS[@]}"; do
    file=$(printf '%s' "$record" | cut -d'|' -f1)
    line=$(printf '%s' "$record" | cut -d'|' -f2)
    content=$(printf '%s' "$record" | cut -d'|' -f3)

    if [[ ${#file} -gt $COL_FILE ]]; then
        file="...${file: -$((COL_FILE - 3))}"
    fi

    printf '  %s%-*s%s  %-*s  %s%-*s%s\n' \
        "$RED" "$COL_FILE" "$file" "$NC" \
        "$COL_LINE" "$line" \
        "$YELLOW" "$COL_CONTENT" "${content:0:$COL_CONTENT}" "$NC"
done

printf '\n'
printf '  %sScan Summary%s\n' "$BOLD" "$NC"
printf '  %s────────────────────────────────────────────────%s\n' "$DIM" "$NC"
printf '  %-24s %s\n' "Violations found:" "${#VIOLATIONS[@]}"
printf '\n'
printf '  %s%-24s%s %s%sFAIL%s\n' "$BOLD" "Result:" "$NC" "$RED" "$BOLD" "$NC"
printf '\n'

printf '  %s%sAction:%s Replace hardcoded hex values with Color("CadenceTokenName")\n' "$YELLOW" "$BOLD" "$NC"
printf '         from the design system asset catalog.\n'
printf '\n'
printf '  %sSee: docs/CADENCE_DESIGN_DOCS/Cadence_Design_Spec_v1.1.md S3%s\n' "$DIM" "$NC"
printf '\n'

exit 1
