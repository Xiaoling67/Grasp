#!/usr/bin/env bash
# Step 1 of the Engineer Loop (see AGENTS.md): create a PM spec task.
#
# Usage: new-feature.sh "<feature 标题>" "<Founder 的原始需求描述>"
# Prints the created task id on stdout (full JSON goes to stderr).
set -euo pipefail

if [ "$#" -lt 1 ]; then
  echo "Usage: $0 \"<title>\" [\"<body>\"]" >&2
  exit 1
fi

TITLE="$1"
BODY="${2:-}"

JSON=$(hermes kanban --board grasp create "$TITLE" \
  --body "$BODY" \
  --assignee pm \
  --created-by cos \
  --json)

echo "$JSON" >&2
echo "$JSON" | jq -r '.id'
