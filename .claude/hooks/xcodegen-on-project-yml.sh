#!/bin/bash
# xcodegen-on-project-yml.sh
#
# PostToolUse hook. Fires after any Write or Edit tool call.
# When the target file is project.yml, immediately runs xcodegen generate.
#
# --- PostToolUse blocking contract (official Anthropic Claude Code spec) ---
# The tool has already run. Exit code 2 is NOT a hard block for PostToolUse:
# it only shows stderr to Claude as non-blocking feedback.
#
# The official blocking mechanism for PostToolUse is:
#   exit 0 + JSON {"decision": "block", "reason": "..."} on stdout
#   → Claude receives the reason and must address it before continuing.
#
# Exit 0 with no JSON → Claude continues normally.
# -------------------------------------------------------------------------

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on writes targeting project.yml
if [[ -z "$FILE_PATH" ]] || [[ "$(basename "$FILE_PATH")" != "project.yml" ]]; then
  exit 0
fi

# Locate xcodegen (resolve at runtime, not hardcoded)
XCODEGEN_BIN=$(command -v xcodegen 2>/dev/null || true)

if [[ -z "$XCODEGEN_BIN" ]]; then
  jq -n '{
    decision: "block",
    reason: "xcodegen generate could not run: xcodegen is not installed or not in PATH.\nInstall it: brew install xcodegen\n\nproject.yml was written but the Xcode project was NOT regenerated.\nDo not continue writing Swift files until xcodegen is available."
  }'
  exit 0
fi

# Run xcodegen from the directory containing the project.yml that was just written
PROJECT_DIR=$(dirname "$FILE_PATH")
XCODEGEN_OUTPUT=$(cd "$PROJECT_DIR" && "$XCODEGEN_BIN" generate --spec project.yml 2>&1)
XCODEGEN_EXIT=$?

if [[ $XCODEGEN_EXIT -ne 0 ]]; then
  jq -n --arg out "$XCODEGEN_OUTPUT" '{
    decision: "block",
    reason: ("xcodegen generate failed after writing project.yml.\n\nThe Xcode project was NOT regenerated. Do not write Swift files or make further changes until this is resolved — the project state is stale.\n\nxcodegen output:\n" + $out + "\n\nTo fix:\n  1. Correct the error in project.yml.\n  2. Re-write project.yml with the corrected content.\n  3. xcodegen will re-run automatically. Confirm it succeeds before continuing.")
  }'
  exit 0
fi

# xcodegen succeeded — allow Claude to continue
exit 0
