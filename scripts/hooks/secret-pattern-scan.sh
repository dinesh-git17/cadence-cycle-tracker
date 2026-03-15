#!/usr/bin/env bash
# secret-pattern-scan.sh
# Pre-commit hook -- detects Cadence-specific secret patterns in staged files.
# Complements pre-commit's detect-private-key with project-specific patterns.
#
# Exit codes:
#   0  Clean
#   1  Secret pattern(s) detected

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

SECRET_PATTERNS=(
    'SUPABASE_KEY\s*='
    'SUPABASE_URL\s*='
    'SUPABASE_ANON_KEY\s*='
    'SUPABASE_SERVICE_ROLE_KEY\s*='
    'APNS_KEY_ID\s*='
    'APNS_TEAM_ID\s*='
    'supabase_key\s*='
    'supabase_url\s*='
    'sk_live_[a-zA-Z0-9]'
    'pk_live_[a-zA-Z0-9]'
    'eyJhbGciOiJ'
    'ghp_[a-zA-Z0-9]{36}'
    'gho_[a-zA-Z0-9]{36}'
    'xoxb-[0-9]'
    'xoxp-[0-9]'
)

PATTERN_NAMES=(
    "SUPABASE_KEY assignment"
    "SUPABASE_URL assignment"
    "SUPABASE_ANON_KEY assignment"
    "SUPABASE_SERVICE_ROLE_KEY assignment"
    "APNS_KEY_ID assignment"
    "APNS_TEAM_ID assignment"
    "supabase_key assignment"
    "supabase_url assignment"
    "Stripe live secret key"
    "Stripe live publishable key"
    "JWT token (eyJ prefix)"
    "GitHub personal access token"
    "GitHub OAuth token"
    "Slack bot token"
    "Slack user token"
)

SKIP_EXTENSIONS=("png" "jpg" "jpeg" "gif" "ico" "svg" "webp" "woff" "woff2" "ttf" "otf" "pdf" "zip" "tar" "gz" "mp3" "mp4" "wav" "ipa" "car" "mobileprovision" "p8" "p12" "db" "lock" "lockb")

VIOLATIONS=()

for file in "$@"; do
    if [[ ! -f "$file" ]]; then
        continue
    fi

    ext="${file##*.}"
    skip=false
    for skip_ext in "${SKIP_EXTENSIONS[@]}"; do
        if [[ "$ext" == "$skip_ext" ]]; then
            skip=true
            break
        fi
    done
    [[ "$skip" == true ]] && continue

    basename_file=$(basename "$file")
    if [[ "$basename_file" == ".env" || "$basename_file" == ".env."* ]]; then
        if [[ "$basename_file" == *.example ]]; then
            continue
        else
            VIOLATIONS+=("${file}|0|.env file staged for commit")
            continue
        fi
    fi

    for i in "${!SECRET_PATTERNS[@]}"; do
        pattern="${SECRET_PATTERNS[$i]}"
        name="${PATTERN_NAMES[$i]}"
        matches=$(grep -nE "$pattern" "$file" 2>/dev/null || true)
        if [[ -n "$matches" ]]; then
            while IFS= read -r match; do
                line_num=$(printf '%s' "$match" | cut -d: -f1)
                VIOLATIONS+=("${file}|${line_num}|${name}")
            done <<< "$matches"
        fi
    done
done

if [[ ${#VIOLATIONS[@]} -eq 0 ]]; then
    exit 0
fi

printf '\n'
printf '%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════'
printf '%s  Cadence  --  Secret Pattern Detection%s\n' "$BOLD" "$NC"
printf '%s%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════' "$NC"
printf '\n'

printf '%s%s─── Staged File Scan %s\n\n' "$CYAN" "$BOLD" "$NC"

COL_FILE=40
COL_LINE=5
COL_PATTERN=30

sep_file=$(printf '%0.s─' $(seq 1 "$COL_FILE"))
sep_line=$(printf '%0.s─' $(seq 1 "$COL_LINE"))
sep_pattern=$(printf '%0.s─' $(seq 1 "$COL_PATTERN"))

printf '  %s%-*s  %-*s  %-*s  %s%s\n' \
    "$BOLD" \
    "$COL_FILE" "FILE" \
    "$COL_LINE" "LINE" \
    "$COL_PATTERN" "PATTERN" \
    "SEVERITY" \
    "$NC"
printf '  %s%-*s  %-*s  %-*s  %s%s\n' \
    "$DIM" \
    "$COL_FILE" "$sep_file" \
    "$COL_LINE" "$sep_line" \
    "$COL_PATTERN" "$sep_pattern" \
    "────────" \
    "$NC"

for record in "${VIOLATIONS[@]}"; do
    file=$(printf '%s' "$record" | cut -d'|' -f1)
    line=$(printf '%s' "$record" | cut -d'|' -f2)
    name=$(printf '%s' "$record" | cut -d'|' -f3)

    if [[ ${#file} -gt $COL_FILE ]]; then
        file="...${file: -$((COL_FILE - 3))}"
    fi

    printf '  %s%-*s%s  %-*s  %s%-*s%s  %sCRITICAL%s\n' \
        "$RED" "$COL_FILE" "$file" "$NC" \
        "$COL_LINE" "$line" \
        "$YELLOW" "$COL_PATTERN" "${name:0:$COL_PATTERN}" "$NC" \
        "$RED" "$NC"
done

printf '\n'
printf '  %sScan Summary%s\n' "$BOLD" "$NC"
printf '  %s────────────────────────────────────────────────%s\n' "$DIM" "$NC"
printf '  %-24s %s\n' "Violations found:" "${#VIOLATIONS[@]}"
printf '\n'
printf '  %s%-24s%s %s%sFAIL%s\n' "$BOLD" "Result:" "$NC" "$RED" "$BOLD" "$NC"
printf '\n'

printf '  %s%sAction:%s Secrets must never be committed to source control.\n' "$YELLOW" "$BOLD" "$NC"
printf '         Use .env files (gitignored) or environment variables.\n'
printf '\n'
printf '  %sSee: CLAUDE.md S5 (Security)%s\n' "$DIM" "$NC"
printf '\n'

exit 1
