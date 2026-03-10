#!/bin/bash
# build-health-check.sh
#
# SessionStart hook (matcher: startup). Runs a clean build at session open and
# writes the health summary to stdout. Stdout on exit 0 is added directly to
# Claude's context — the official SessionStart output mechanism per the Claude
# Code hooks spec. Claude sees the build health before touching any file.
#
# --- SessionStart output contract (official Anthropic Claude Code spec) ---
#   exit 0  → stdout is added to Claude's context
#   exit 2  → stderr shown to user only (Claude never sees it)
# Always exit 0 so Claude receives the health report regardless of build outcome.
# -------------------------------------------------------------------------
#
# Build command: canonical from cadence-build skill
#   xcodebuild -scheme Cadence
#              -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0'
#              clean build
#   | xcbeautify --quiet
#
# xcbeautify --quiet suppresses passing steps; surfaces only warnings, errors,
# and the build summary — giving the last 5 lines maximum signal density.

set -uo pipefail

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# If the project has not been generated yet, report gracefully and exit.
if [[ ! -d "$PROJECT_DIR/Cadence.xcodeproj" ]]; then
  echo "=== Cadence Build Health: SKIPPED ==="
  echo "Cadence.xcodeproj not found. Project has not been generated yet."
  echo "Run: xcodegen generate --spec project.yml"
  exit 0
fi

# Require xcbeautify (cadence-build skill mandates it for all xcodebuild output).
XCBEAUTIFY_BIN=$(command -v xcbeautify 2>/dev/null || true)
if [[ -z "$XCBEAUTIFY_BIN" ]]; then
  echo "=== Cadence Build Health: SKIPPED ==="
  echo "xcbeautify is not installed. Install: brew install xcbeautify"
  exit 0
fi

# Temp file to capture build output. Cleaned up on script exit.
TMPFILE=$(mktemp)
trap 'rm -f "$TMPFILE"' EXIT

cd "$PROJECT_DIR"

# Run clean build. Pipe through xcbeautify --quiet (suppress passing steps;
# show warnings, errors, and build summary only).
# PIPESTATUS[0] captures xcodebuild's exit code after the pipe.
xcodebuild \
  -scheme Cadence \
  -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \
  clean build 2>&1 \
  | "$XCBEAUTIFY_BIN" --quiet > "$TMPFILE" 2>&1
BUILD_EXIT=${PIPESTATUS[0]}

LAST_5=$(tail -5 "$TMPFILE")

if [[ $BUILD_EXIT -eq 0 ]]; then
  cat <<MSG
=== Cadence Build Health: PASSED ===
Clean build succeeded at session start. The project is healthy.
Do not run another clean build unless you have a reason (stale artifacts, branch switch, pre-submission).

Last 5 lines of build output:
$LAST_5
MSG
else
  cat <<MSG
=== Cadence Build Health: FAILED ===
Clean build FAILED at session start. The project was already broken before this session began.
Do not write new Swift files or generate new code until the build error is resolved.

Last 5 lines of xcodebuild output (via xcbeautify --quiet):
$LAST_5

To investigate in full:
  cd "$PROJECT_DIR"
  set -o pipefail && xcodebuild -scheme Cadence \\
    -destination 'platform=iOS Simulator,name=iPhone 16 Pro,OS=26.0' \\
    clean build 2>&1 | xcbeautify
MSG
fi

exit 0
