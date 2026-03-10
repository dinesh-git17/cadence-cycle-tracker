#!/bin/bash
# no-hex-in-swift.sh
#
# PostToolUse warn hook. Fires after any Write or Edit tool call.
# When the target file is a .swift file, greps it for bare six-digit hex
# literals (#RRGGBB). Warns Claude on any match so it can replace the
# literal with the correct Color("CadenceTokenName") reference.
#
# Rule source: Cadence Design Spec v1.1 and cadence-design-system skill:
#   "No hardcoded hex values in Swift source. All colors must reference
#    named Color assets from xcassets using Color("TokenName")."
#
# --- PostToolUse warn contract (official Anthropic Claude Code spec) ---
# The tool has already run. For warn (not block) behavior:
#
#   exit 2 + stderr  → shows stderr to Claude as non-blocking feedback.
#                       Claude sees the match and replaces it next turn
#                       without being hard-stopped mid-implementation.
#
# The hard-block alternative (NOT used here) is:
#   exit 0 + JSON {"decision": "block", "reason": "..."} on stdout.
#
# Exit 0 with no output → Claude continues normally (no violations found).
# -----------------------------------------------------------------------

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on .swift files; exit silently for everything else
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.swift ]]; then
  exit 0
fi

# File must exist on disk (Write creates it; Edit modifies it in place)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Grep the file for bare six-digit hex literals (#RRGGBB).
# \b word boundary prevents matching 8-char RGBA values (#RRGGBBAA).
# -n includes line numbers for actionable output.
# -E enables extended regex for the {6} quantifier.
# -i makes the hex letter match case-insensitive (A-F and a-f).
HEX_MATCHES=$(grep -nEi '#[0-9A-Fa-f]{6}\b' "$FILE_PATH" 2>/dev/null || true)

# No matches — proceed silently
if [[ -z "$HEX_MATCHES" ]]; then
  exit 0
fi

# Matches found — surface to Claude as non-blocking warn.
# PostToolUse + exit 2 = stderr shown to Claude; cannot block the already-completed write.
FILENAME=$(basename "$FILE_PATH")
cat >&2 <<MSG
[no-hex-in-swift] Bare hex literals found in ${FILENAME}:

${HEX_MATCHES}

VIOLATION: Hardcoded hex colors are prohibited by the Cadence Design Spec v1.1.
All Swift color references must use named xcassets tokens via Color("TokenName").

Valid Cadence tokens:
  Color("CadenceBackground")    — App-wide background
  Color("CadenceCard")          — Card/sheet surfaces
  Color("CadenceTerracotta")    — Primary accent (CTAs, active chips, active tab)
  Color("CadenceSage")          — Secondary accent (fertility, insight cards)
  Color("CadenceSageLight")     — Sage tinted surfaces
  Color("CadenceTextPrimary")   — Body copy, headings
  Color("CadenceTextSecondary") — Subtitles, metadata, placeholders
  Color("CadenceTextOnAccent")  — Text on terracotta fills
  Color("CadenceBorder")        — Card strokes, chip outlines, input borders
  Color("CadenceDestructive")   — Account deletion / disconnect CTAs only

Replace each hex literal with the matching token above. If the hex value does
not map to any token, it is not sanctioned by the spec — consult the design
system skill before proceeding.
MSG

exit 2
