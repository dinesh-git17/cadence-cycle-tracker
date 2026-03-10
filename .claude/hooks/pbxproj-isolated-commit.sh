#!/bin/bash
# pbxproj-isolated-commit.sh
#
# PostToolUse hook (matcher: Write|Edit). Fires when project.yml is written.
# Checks whether the current git staging area mixes XcodeGen project-structure
# changes with Swift source changes — the anti-pattern from cadence-git §3/§4.
#
# --- PostToolUse warn contract (official Anthropic Claude Code spec) ---
#   exit 2  → stderr shown to Claude as non-blocking feedback (Can block? No)
#   exit 0  → silent pass, Claude continues normally
# Never use exit 0 + {"decision":"block"} here — that would hard-block, which
# violates the warn-only intent. exit 2 is the official warn path for PostToolUse.
# -----------------------------------------------------------------------
#
# Cadence-git §3 mixed-commit anti-pattern (the condition we detect):
#   Staged: *.swift (product logic) + project.yml or *.pbxproj (project structure)
#
# Cadence-git §3 Case 1 (NOT flagged — allowed):
#   Staged: *.swift (new file) + Cadence.xcodeproj ONLY (file registration artifact)
#   → This hook never fires on Case 1 because it only triggers on project.yml writes,
#     and new-file registration does not require a project.yml change when sources: glob.
#
# If git is not initialized, the staging check returns empty and this hook exits 0.

INPUT=$(cat)
FILE_PATH=$(echo "$INPUT" | jq -r '.tool_input.file_path // empty')

# Only act on writes targeting project.yml
if [[ -z "$FILE_PATH" ]] || [[ "$(basename "$FILE_PATH")" != "project.yml" ]]; then
  exit 0
fi

PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Read the staged file list. If git is absent or repo not initialised, returns empty.
STAGED=$(git -C "$PROJECT_DIR" diff --cached --name-only 2>/dev/null || true)

if [[ -z "$STAGED" ]]; then
  exit 0  # Nothing staged — no mixing possible
fi

# --- Project-structure category ---
# project.yml staged (structural config) or .pbxproj staged (generated artifact).
PROJ_STAGED=$(echo "$STAGED" | grep -E '(\.pbxproj$|\.xcodeproj/|^project\.yml$)' || true)

# --- Product-logic category ---
# Swift source files in any Cadence source directory.
SWIFT_STAGED=$(echo "$STAGED" | grep -E '\.swift$' || true)

# No mixing → clean state
if [[ -z "$PROJ_STAGED" ]] || [[ -z "$SWIFT_STAGED" ]]; then
  exit 0
fi

# Mixed staging detected. Count files for the warning.
PROJ_COUNT=$(echo "$PROJ_STAGED" | grep -c . 2>/dev/null || echo "0")
SWIFT_COUNT=$(echo "$SWIFT_STAGED" | grep -c . 2>/dev/null || echo "0")

SWIFT_LIST=$(echo "$SWIFT_STAGED" | sed 's/^/  /')
PROJ_LIST=$(echo "$PROJ_STAGED" | sed 's/^/  /')

cat >&2 <<MSG
WARNING: Mixed staging detected — cadence-git §3 (.pbxproj isolation rule)

project.yml was just modified. The git staging area currently mixes
project-structure changes with Swift source changes:

  Project-structure files staged ($PROJ_COUNT):
$PROJ_LIST

  Swift source files staged ($SWIFT_COUNT):
$SWIFT_LIST

Per cadence-git §3, .pbxproj regenerations and project.yml config changes
must be isolated into their own chore(project): commit. Mixing them with
Swift feature work makes PR diffs unreadable and rollbacks unpredictable.

Split the commit before staging:
  1. Commit Swift changes first (no project.yml or Cadence.xcodeproj):
       git add <swift files>
       git commit -m "feat(scope): <description>"

  2. Then commit the project structure separately:
       git add project.yml Cadence.xcodeproj
       git commit -m "chore(project): <describe the XcodeGen change>"

See cadence-git skill §3 for the full three-case breakdown and examples.
MSG

exit 2
