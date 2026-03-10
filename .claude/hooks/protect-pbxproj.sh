#!/bin/bash
# protect-pbxproj.sh
#
# PreToolUse hard-block hook. Fires before any Write or Edit tool call.
# Blocks any attempt to write directly to a .pbxproj file.
#
# Cadence.xcodeproj/project.pbxproj is a XcodeGen build artifact.
# The source of truth is project.yml. Direct edits are prohibited.
#
# Hard-block contract (official Anthropic Claude Code hook spec):
#   exit 2  — blocks the tool call; stderr is fed to Claude as feedback
#   exit 0  — allows the tool call to proceed

set -euo pipefail

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

if [[ -z "$FILE_PATH" ]]; then
  exit 0
fi

if [[ "$FILE_PATH" == *.pbxproj ]]; then
  cat >&2 <<'MSG'
BLOCKED: Direct writes to .pbxproj files are prohibited.

Cadence.xcodeproj/project.pbxproj is a XcodeGen-generated build artifact,
not a source file. Any direct edit will be overwritten the next time
xcodegen generate runs, and manual edits produce irreproducible state.

To make project-structure changes:
  1. Edit project.yml (repo root) — this is the source of truth.
  2. Run: xcodegen generate --spec project.yml
  3. Commit project.yml + the regenerated Cadence.xcodeproj together.

See .claude/skills/cadence-xcode-project/SKILL.md for the full workflow.
MSG
  exit 2
fi

exit 0
