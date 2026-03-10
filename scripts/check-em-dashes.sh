#!/usr/bin/env bash
# check-em-dashes.sh
# Typographic Lint — Smart Character Detection for Cadence Cycle Tracker
#
# Scans source files for typographic characters (em dashes, en dashes, smart
# quotes) that indicate copy-paste from rich text editors or AI output.
# These characters do not belong in source code — use ASCII equivalents.
#
# Hard-exempt paths: docs/, .claude/, CLAUDE.md — prose files where
# typographic characters are legitimate.
#
# Usage:
#   ./scripts/check-em-dashes.sh                  Scan entire codebase
#   ./scripts/check-em-dashes.sh --dir <path>     Scan specific directory
#   ./scripts/check-em-dashes.sh --help            Usage
#
# Exit codes:
#   0  Clean — no violations detected
#   1  Violation(s) detected

set -euo pipefail

# ---------------------------------------------------------------------------
# ANSI color codes (ANSI C quoting for printf compatibility)
# ---------------------------------------------------------------------------
RED=$'\033[0;31m'
GREEN=$'\033[0;32m'
YELLOW=$'\033[0;33m'
CYAN=$'\033[0;36m'
BOLD=$'\033[1m'
DIM=$'\033[2m'
NC=$'\033[0m'

# ---------------------------------------------------------------------------
# Typographic characters to detect
# ---------------------------------------------------------------------------
EM_DASH=$'\xe2\x80\x94'          # U+2014
EN_DASH=$'\xe2\x80\x93'          # U+2013
LEFT_DOUBLE_QUOTE=$'\xe2\x80\x9c' # U+201C
RIGHT_DOUBLE_QUOTE=$'\xe2\x80\x9d' # U+201D
LEFT_SINGLE_QUOTE=$'\xe2\x80\x98' # U+2018
RIGHT_SINGLE_QUOTE=$'\xe2\x80\x99' # U+2019

TYPOGRAPHIC_CHARS=(
    "$EM_DASH"
    "$EN_DASH"
    "$LEFT_DOUBLE_QUOTE"
    "$RIGHT_DOUBLE_QUOTE"
    "$LEFT_SINGLE_QUOTE"
    "$RIGHT_SINGLE_QUOTE"
)

TYPOGRAPHIC_NAMES=(
    "EM DASH (U+2014)"
    "EN DASH (U+2013)"
    "LEFT DBL QUOTE (U+201C)"
    "RIGHT DBL QUOTE (U+201D)"
    "LEFT SGL QUOTE (U+2018)"
    "RIGHT SGL QUOTE (U+2019)"
)

TYPOGRAPHIC_REPLACEMENTS=(
    "--"
    "-"
    "\""
    "\""
    "'"
    "'"
)

# ---------------------------------------------------------------------------
# Hard-exempt paths — NEVER scanned. Prose files where typographic
# characters are legitimate content, not code defects.
# ---------------------------------------------------------------------------
HARD_EXEMPT_DIRS=(
    "docs"
    ".claude"
)

HARD_EXEMPT_FILES=(
    "CLAUDE.md"
    "protocol-zero.sh"
    "check-em-dashes.sh"
    "settings.local.json"
    "MEMORY.md"
)

# ---------------------------------------------------------------------------
# Directory exclusions — build artifacts, toolchain caches, generated output.
# Mirrors protocol-zero.sh conventions for iOS/Xcode projects.
# ---------------------------------------------------------------------------
EXCLUDE_DIRS=(
    ".git"
    ".claude"
    "docs"
    "build"
    "DerivedData"
    "xcuserdata"
    ".swiftpm"
    ".build"
    "node_modules"
)

# ---------------------------------------------------------------------------
# Binary and non-source extensions — skipped during scan.
# Includes .md (markdown is prose; typographic chars are legitimate there).
# ---------------------------------------------------------------------------
BINARY_EXTENSIONS=(
    "png" "jpg" "jpeg" "gif" "ico" "svg" "webp"
    "woff" "woff2" "ttf" "eot" "otf"
    "pdf" "zip" "tar" "gz" "bz2"
    "mp3" "mp4" "wav" "avi" "mov"
    "m4a" "aac"
    "ipa" "car" "mobileprovision"
    "db" "db-wal" "db-shm"
    "lock" "lockb"
    "p8"
    "skill"
    "xcframework"
    "md"
)

# ---------------------------------------------------------------------------
# Violation tracking
# ---------------------------------------------------------------------------
VIOLATIONS_FOUND=0
VIOLATION_RECORDS=()   # Each element: "filepath|line_num|char_name|content"

# ---------------------------------------------------------------------------
# Output helpers — matches protocol-zero.sh conventions
# ---------------------------------------------------------------------------
print_banner() {
    printf '\n'
    printf '%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════'
    printf '%s  Cadence  —  Typographic Lint  [Smart Character Detection]%s\n' "$BOLD" "$NC"
    printf '%s%s%s\n' "$BOLD" '══════════════════════════════════════════════════════════════' "$NC"
    printf '\n'
}

print_section() {
    printf '%s%s─── %s %s\n' "$CYAN" "$BOLD" "$1" "$NC"
    printf '\n'
}

print_pass() {
    printf '  %s%s[PASS]%s  %s\n' "$GREEN" "$BOLD" "$NC" "$1"
}

print_fail() {
    printf '  %s%s[FAIL]%s  %s\n' "$RED" "$BOLD" "$NC" "$1"
}

print_warn() {
    printf '  %s%s[WARN]%s  %s\n' "$YELLOW" "$BOLD" "$NC" "$1"
}

print_info() {
    printf '  %s[INFO]%s  %s\n' "$DIM" "$NC" "$1"
}

# ---------------------------------------------------------------------------
# Build grep exclusion flag arrays.
# Returns one flag per line for safe array reconstruction.
# ---------------------------------------------------------------------------
build_grep_exclude_args() {
    for dir in "${EXCLUDE_DIRS[@]}"; do
        printf '%s\n' "--exclude-dir=${dir}"
    done
    for ext in "${BINARY_EXTENSIONS[@]}"; do
        printf '%s\n' "--exclude=*.${ext}"
    done
    for file in "${HARD_EXEMPT_FILES[@]}"; do
        printf '%s\n' "--exclude=${file}"
    done
}

# ---------------------------------------------------------------------------
# Check whether a resolved file path is hard-exempt.
# Secondary guard after grep exclusions (belt-and-suspenders).
# ---------------------------------------------------------------------------
is_hard_exempt() {
    local filepath="$1"
    local filename
    filename=$(basename "$filepath")

    for exempt_file in "${HARD_EXEMPT_FILES[@]}"; do
        if [[ "$filename" == "$exempt_file" ]]; then
            return 0
        fi
    done

    for exempt_dir in "${HARD_EXEMPT_DIRS[@]}"; do
        if [[ "$filepath" == *"/${exempt_dir}/"* || "$filepath" == "${exempt_dir}/"* ]]; then
            return 0
        fi
    done

    return 1
}

# ---------------------------------------------------------------------------
# Count scannable files in a directory tree.
# Mirrors grep exclusion logic using find -prune for directory exclusion.
# ---------------------------------------------------------------------------
count_scannable_files() {
    local root_dir="$1"

    find "$root_dir" \
        -name ".git"          -prune -o \
        -name ".claude"       -prune -o \
        -name "docs"          -prune -o \
        -name "build"         -prune -o \
        -name "DerivedData"   -prune -o \
        -name "xcuserdata"    -prune -o \
        -name ".swiftpm"      -prune -o \
        -name ".build"        -prune -o \
        -name "node_modules"  -prune -o \
        -type f \
        ! -name "*.png"   ! -name "*.jpg"  ! -name "*.jpeg" ! -name "*.gif" \
        ! -name "*.ico"   ! -name "*.svg"  ! -name "*.webp" \
        ! -name "*.woff"  ! -name "*.woff2" ! -name "*.ttf" ! -name "*.otf" \
        ! -name "*.pdf"   ! -name "*.zip"  ! -name "*.tar"  ! -name "*.gz" \
        ! -name "*.mp3"   ! -name "*.mp4"  ! -name "*.wav" \
        ! -name "*.m4a"   ! -name "*.aac" \
        ! -name "*.ipa"   ! -name "*.car"  ! -name "*.mobileprovision" \
        ! -name "*.db"    ! -name "*.db-wal" ! -name "*.db-shm" \
        ! -name "*.p8"    ! -name "*.lock" ! -name "*.lockb" \
        ! -name "*.skill" ! -name "*.xcframework" ! -name "*.md" \
        -print 2>/dev/null \
    | wc -l \
    | tr -d ' '
}

# ---------------------------------------------------------------------------
# Print violations as an aligned table.
# Columns: FILE (40), LINE (5), CHARACTER (26), SEVERITY
# ---------------------------------------------------------------------------
print_violations_table() {
    if [[ ${#VIOLATION_RECORDS[@]} -eq 0 ]]; then
        return
    fi

    local COL_FILE=40
    local COL_LINE=5
    local COL_CHAR=26

    local sep_file sep_line sep_char
    sep_file=$(printf '%0.s─' $(seq 1 "$COL_FILE"))
    sep_line=$(printf '%0.s─' $(seq 1 "$COL_LINE"))
    sep_char=$(printf '%0.s─' $(seq 1 "$COL_CHAR"))

    printf '\n'
    printf '  %s%-*s  %-*s  %-*s  %s%s\n' \
        "$BOLD" \
        "$COL_FILE" "FILE" \
        "$COL_LINE" "LINE" \
        "$COL_CHAR" "CHARACTER" \
        "SEVERITY" \
        "$NC"
    printf '  %s%-*s  %-*s  %-*s  %s%s\n' \
        "$DIM" \
        "$COL_FILE" "$sep_file" \
        "$COL_LINE" "$sep_line" \
        "$COL_CHAR" "$sep_char" \
        "────────" \
        "$NC"

    for record in "${VIOLATION_RECORDS[@]}"; do
        local file line char_name
        file=$(printf '%s' "$record"      | cut -d'|' -f1)
        line=$(printf '%s' "$record"      | cut -d'|' -f2)
        char_name=$(printf '%s' "$record" | cut -d'|' -f3)

        if [[ ${#file} -gt $COL_FILE ]]; then
            file="…${file: -$((COL_FILE - 1))}"
        fi

        printf '  %s%-*s%s  %-*s  %s%-*s%s  %sERROR%s\n' \
            "$RED" \
            "$COL_FILE" "$file" \
            "$NC" \
            "$COL_LINE" "$line" \
            "$YELLOW" \
            "$COL_CHAR" "${char_name:0:$COL_CHAR}" \
            "$NC" \
            "$RED" \
            "$NC"
    done

    printf '\n'
}

# ---------------------------------------------------------------------------
# Print the scan summary panel.
# ---------------------------------------------------------------------------
print_summary() {
    local files_scanned="$1"
    local violation_count="$2"

    printf '\n'
    printf '  %sScan Summary%s\n' "$BOLD" "$NC"
    printf '  %s%s%s\n' "$DIM" '────────────────────────────────────────────────' "$NC"
    printf '  %-24s %s\n' "Files scanned:"     "$files_scanned"
    printf '  %-24s %s\n' "Violations found:"  "$violation_count"
    printf '  %-24s %s\n' "Hard-exempt paths:" "docs/  .claude/  CLAUDE.md"
    printf '  %-24s %s\n' "Skipped formats:"   "*.md (prose), binaries, assets"
    printf '\n'

    if [[ "$violation_count" -eq 0 ]]; then
        printf '  %s%-24s%s %s%sPASS%s\n' "$BOLD" "Result:" "$NC" "$GREEN" "$BOLD" "$NC"
    else
        printf '  %s%-24s%s %s%sFAIL%s\n' "$BOLD" "Result:" "$NC" "$RED" "$BOLD" "$NC"
    fi

    printf '\n'
}

# ---------------------------------------------------------------------------
# Print actionable remediation guidance.
# ---------------------------------------------------------------------------
print_remediation() {
    printf '  %s%sAction:%s Replace typographic characters with ASCII equivalents:\n' "$YELLOW" "$BOLD" "$NC"
    printf '\n'
    printf '  %s%-28s%s  %s→%s  %s\n' "$DIM" "  em dash  (U+2014)" "$NC" "$CYAN" "$NC" "--"
    printf '  %s%-28s%s  %s→%s  %s\n' "$DIM" "  en dash  (U+2013)" "$NC" "$CYAN" "$NC" "-"
    printf '  %s%-28s%s  %s→%s  %s\n' "$DIM" "  smart double quotes"  "$NC" "$CYAN" "$NC" "\""
    printf '  %s%-28s%s  %s→%s  %s\n' "$DIM" "  smart single quotes"  "$NC" "$CYAN" "$NC" "'"
    printf '\n'
    printf '  %sTip:%s These characters typically appear when pasting from AI chat,\n' "$DIM" "$NC"
    printf '  %s     rich text editors, or macOS autocorrect. Disable Smart Quotes\n' "$DIM"
    printf '       in System Settings > Keyboard > Text Replacements.%s\n' "$NC"
    printf '\n'
}

# ---------------------------------------------------------------------------
# Full codebase scan
# ---------------------------------------------------------------------------
scan_codebase() {
    local root_dir="${1:-.}"

    print_banner
    print_section "Codebase Scan"
    print_info "Root:         ${root_dir}"
    print_info "Hard-exempt:  docs/  .claude/  CLAUDE.md"
    print_info "Targets:      *.swift  *.yml  *.sh  *.json  (all non-exempt source)"
    printf '\n'

    local grep_exclude_args=()
    while IFS= read -r arg; do
        grep_exclude_args+=("$arg")
    done < <(build_grep_exclude_args)

    for i in "${!TYPOGRAPHIC_CHARS[@]}"; do
        local char="${TYPOGRAPHIC_CHARS[$i]}"
        local char_name="${TYPOGRAPHIC_NAMES[$i]}"

        local matching_files
        matching_files=$(grep -rlF "${grep_exclude_args[@]}" "$char" "$root_dir" 2>/dev/null || true)

        [[ -z "$matching_files" ]] && continue

        while IFS= read -r filepath; do
            if is_hard_exempt "$filepath"; then
                continue
            fi

            local line_matches
            line_matches=$(grep -nF "$char" "$filepath" 2>/dev/null || true)

            [[ -z "$line_matches" ]] && continue

            VIOLATIONS_FOUND=1

            while IFS= read -r line_match; do
                local line_num
                line_num=$(printf '%s' "$line_match" | cut -d: -f1)
                local content
                content=$(printf '%s' "$line_match" | cut -d: -f2-)
                VIOLATION_RECORDS+=("${filepath}|${line_num}|${char_name}|${content:0:60}")
            done <<< "$line_matches"

        done <<< "$matching_files"
    done

    local files_scanned
    files_scanned=$(count_scannable_files "$root_dir")

    if [[ $VIOLATIONS_FOUND -eq 1 ]]; then
        print_violations_table
        print_summary "$files_scanned" "${#VIOLATION_RECORDS[@]}"
        print_fail "Typographic characters detected in source code."
        printf '\n'
        print_remediation
        return 1
    else
        print_summary "$files_scanned" 0
        print_pass "No typographic characters detected in source code."
        printf '\n'
        return 0
    fi
}

# ---------------------------------------------------------------------------
# Entry point
# ---------------------------------------------------------------------------
main() {
    local scan_dir="."

    while [[ $# -gt 0 ]]; do
        case "$1" in
            --dir)
                scan_dir="$2"
                shift 2
                ;;
            --help|-h)
                printf 'Cadence — Typographic Lint (Smart Character Detection)\n\n'
                printf 'Usage:\n'
                printf '  %s                     Scan entire codebase\n' "$0"
                printf '  %s --dir <path>        Scan specific directory\n' "$0"
                printf '\nDetects:\n'
                for i in "${!TYPOGRAPHIC_NAMES[@]}"; do
                    printf '  %s  →  replace with %s\n' "${TYPOGRAPHIC_NAMES[$i]}" "${TYPOGRAPHIC_REPLACEMENTS[$i]}"
                done
                printf '\nExit codes:\n'
                printf '  0  No violations\n'
                printf '  1  Violation(s) detected\n'
                exit 0
                ;;
            *)
                printf '%sUnknown argument: %s%s\n' "$YELLOW" "$1" "$NC" >&2
                shift
                ;;
        esac
    done

    scan_codebase "$scan_dir"
}

main "$@"
