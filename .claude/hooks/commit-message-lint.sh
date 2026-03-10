#!/bin/bash
# commit-message-lint.sh
#
# PostToolUse warn hook. Fires after any Bash tool call.
# When the command contains "git commit", extracts the inline commit message
# (from -m or --message flags) and validates it against Conventional Commits.
# Warns Claude if the format is wrong so it can amend immediately.
#
# Allowed types (cadence-git skill §1 + CLAUDE.md §7.3):
#   feat, fix, refactor, test, chore, docs, exp
#
# Required format: type[(scope)]: description
#   e.g. feat(tracker): add TrackerHomeView with 5-tab shell
#        chore(project): initialize XcodeGen project.yml
#        fix(auth): resolve session token refresh race
#
# --- PostToolUse warn contract (official Anthropic Claude Code spec) ---
# The tool has already run (the commit landed). For warn (not block):
#
#   exit 2 + stderr  → shows stderr to Claude as non-blocking feedback.
#                       Claude amends the commit in the next turn.
#
# Hard-block alternative (NOT used here):
#   exit 0 + JSON {"decision": "block", "reason": "..."} on stdout.
#
# Exit 0 with no output → commit message is valid or unparseable (skip).
# -----------------------------------------------------------------------

INPUT=$(cat)
COMMAND=$(echo "$INPUT" | jq -r '.tool_input.command // empty')

# Only act on Bash commands that directly invoke git commit.
# We require git commit to appear as a direct invocation: at the start of a
# line or following && or ; — not buried inside a string argument or script body.
# This prevents false positives from test scripts that contain "git commit"
# as text inside string literals or single-quoted arguments.
if [[ -z "$COMMAND" ]]; then
  exit 0
fi

# Extract the first line where git commit is directly invoked.
# Patterns matched: `git commit ...`, `&& git commit ...`, `; git commit ...`
# Each is anchored to a position where git is actually being executed.
GIT_COMMIT_LINE=$(echo "$COMMAND" | \
  grep -Em1 '(^|&&|;)[[:space:]]*git[[:space:]]+commit' | \
  head -1)

if [[ -z "$GIT_COMMIT_LINE" ]]; then
  exit 0
fi

# If the invocation uses --no-edit without -m/--message, the message is from
# the previous commit or an editor session — we cannot inspect it. Skip.
if echo "$GIT_COMMIT_LINE" | grep -qE -- '--no-edit' && \
   ! echo "$GIT_COMMIT_LINE" | grep -qE -- '(-m|--message)[[:space:]]'; then
  exit 0
fi

# Skip if --allow-empty-message is present (no meaningful message to validate)
if echo "$GIT_COMMIT_LINE" | grep -qE -- '--allow-empty-message'; then
  exit 0
fi

# Extract inline commit message from -m or --message on the invocation line only.
# Operating on GIT_COMMIT_LINE (not the full COMMAND) prevents any other content
# in the Bash script from being accidentally matched.
# sed -E (ERE) for portability on macOS BSD sed.
# [^"]+ requires at least one char — empty messages are not extracted.
MSG=$(echo "$GIT_COMMIT_LINE" | sed -nE 's/.*(-m|--message)[[:space:]]+"([^"]+)".*/\2/p' | head -1)

# If not found with double quotes, try single-quoted message
if [[ -z "$MSG" ]]; then
  MSG=$(echo "$GIT_COMMIT_LINE" | sed -nE "s/.*(-m|--message)[[:space:]]+'([^']+)'.*/\2/p" | head -1)
fi

# Could not extract an inline message — skip rather than false-positive
# (covers heredoc, editor-driven commits, shell variable expansions)
if [[ -z "$MSG" ]]; then
  exit 0
fi

# Skip if the extracted "message" is a shell expansion artifact (e.g., "$(cat ...")
if [[ "$MSG" == \$* ]]; then
  exit 0
fi

# Validate against Conventional Commits format.
# Pattern: type[(scope)]: description
# Valid types: feat, fix, chore, refactor, test, docs, exp
VALID_PATTERN='^(feat|fix|chore|refactor|test|docs|exp)(\([^)]+\))?:[[:space:]]'

if echo "$MSG" | grep -qE "$VALID_PATTERN"; then
  # Valid — proceed silently
  exit 0
fi

# Invalid commit message — warn Claude via stderr (non-blocking PostToolUse feedback)
cat >&2 <<MSG_EOF
[commit-message-lint] Non-conforming commit message detected:

  "$MSG"

VIOLATION: Commit messages must follow Conventional Commits format
(cadence-git skill §1, CLAUDE.md §7.3).

Required format:  type[(scope)]: imperative description
Allowed types:    feat | fix | chore | refactor | test | docs | exp

Valid examples:
  feat(tracker): add TrackerHomeView with 5-tab NavigationStack
  fix(auth): resolve session token refresh race condition
  chore(project): initialize XcodeGen project.yml and generate xcodeproj
  refactor(sync): extract SyncCoordinator flush into isolated method
  docs(spec): add cadence-git governance skill

To fix: amend the commit message before pushing or continuing:
  git commit --amend -m "type(scope): imperative description"

Clean, Conventional-Commits-formatted history is required for bisect,
changelog generation, and PR squash merges on this project.
MSG_EOF

exit 2
