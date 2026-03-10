#!/usr/bin/env bash
# protocol-zero-commit-msg.sh
# Commit-msg hook -- runs Protocol Zero scan on the commit message.
# Delegates to scripts/protocol-zero.sh --commit-msg-file.
#
# Pre-commit framework passes the commit message file path as $1.
#
# Exit codes:
#   0  Clean
#   1  Violation(s) detected

set -euo pipefail

REPO_ROOT="$(git rev-parse --show-toplevel)"
SCRIPT="$REPO_ROOT/scripts/protocol-zero.sh"

if [[ ! -x "$SCRIPT" ]]; then
    printf 'protocol-zero-commit-msg: cannot find %s\n' "$SCRIPT" >&2
    exit 1
fi

COMMIT_MSG_FILE="${1:-}"

if [[ -z "$COMMIT_MSG_FILE" || ! -f "$COMMIT_MSG_FILE" ]]; then
    exit 0
fi

"$SCRIPT" --commit-msg-file "$COMMIT_MSG_FILE"
