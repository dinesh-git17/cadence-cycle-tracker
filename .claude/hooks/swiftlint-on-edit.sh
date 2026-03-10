#!/bin/bash
# swiftlint-on-edit.sh
#
# PostToolUse warn hook. Fires after any Write or Edit tool call.
# When the target file is a .swift file, runs SwiftLint on it and
# surfaces any violations to Claude as non-blocking feedback.
#
# --- PostToolUse warn contract (official Anthropic Claude Code spec) ---
# The tool has already run. For warn (not block) behavior:
#
#   exit 2 + stderr  → shows stderr to Claude as non-blocking feedback.
#                       Claude sees violations and fixes them in the next
#                       turn without being hard-stopped mid-implementation.
#
# The hard-block alternative (NOT used here) is:
#   exit 0 + JSON {"decision": "block", "reason": "..."} on stdout
#   → Claude receives the reason and must address it before continuing.
#
# Exit 0 with no output → Claude continues normally (no violations).
# -----------------------------------------------------------------------

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on .swift files; exit silently for everything else
if [[ -z "$FILE_PATH" ]] || [[ "$FILE_PATH" != *.swift ]]; then
  exit 0
fi

# File must exist (Write creates it; Edit updates it in place)
if [[ ! -f "$FILE_PATH" ]]; then
  exit 0
fi

# Locate SwiftLint: prefer PATH resolution, fall back to Homebrew default on macOS
SWIFTLINT_BIN=$(command -v swiftlint 2>/dev/null || true)
if [[ -z "$SWIFTLINT_BIN" ]]; then
  SWIFTLINT_BIN="/opt/homebrew/bin/swiftlint"
fi

# SwiftLint not available — skip silently; never block Claude over a missing tool
if [[ ! -x "$SWIFTLINT_BIN" ]]; then
  exit 0
fi

# Run from project root so SwiftLint resolves .swiftlint.yml correctly.
# CLAUDE_PROJECT_DIR is set by Claude Code for all hook invocations.
if [[ -n "${CLAUDE_PROJECT_DIR:-}" ]]; then
  cd "$CLAUDE_PROJECT_DIR"
fi

# Lint only the specific file that was just written.
# Capturing stderr into the output so violations appear in one stream.
LINT_OUTPUT=$("$SWIFTLINT_BIN" lint "$FILE_PATH" 2>&1)
LINT_EXIT=$?

# SwiftLint exit 0: no violations — proceed silently
if [[ $LINT_EXIT -eq 0 ]]; then
  exit 0
fi

# Violations found — surface to Claude as non-blocking warn.
# PostToolUse + exit 2 = stderr shown to Claude, cannot block the already-completed write.
cat >&2 <<MSG
[swiftlint-on-edit] SwiftLint violations in $(basename "$FILE_PATH"):

$LINT_OUTPUT

Fix the violations above before moving to the next file. Implementation is not
blocked — this is a warning. Address these in the next edit pass.
MSG

exit 2
