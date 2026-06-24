#!/usr/bin/env bash
# Step 3 of the Engineer Loop (see AGENTS.md): fan out QA + Finance checks
# against the exact worktree Engineer just used (not their own scratch sandbox).
#
# Usage: qa-check.sh <engineer_task_id> <slug>
# Prints the created task ids on stdout (one per line).
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <engineer_task_id> <slug>" >&2
  exit 1
fi

ENG_TASK="$1"
SLUG="$2"

WS_PATH=$(hermes kanban --board grasp show "$ENG_TASK" --json | jq -r '.workspace_path // empty')

if [ -z "$WS_PATH" ]; then
  echo "engineer task $ENG_TASK has no resolved workspace_path yet — has it actually run and committed?" >&2
  exit 1
fi

echo "Engineer workspace: $WS_PATH" >&2

create_qa_task() {
  local profile="$1" title="$2"
  local json
  json=$(hermes kanban --board grasp create "$title" \
    --assignee "$profile" \
    --parent "$ENG_TASK" \
    --workspace "dir:$WS_PATH" \
    --created-by cos \
    --json)
  echo "$json" >&2
  echo "$json" | jq -r '.id'
}

create_qa_task qa      "QA 三维验收: 逻辑 / UX / 场景回放 — $SLUG"
create_qa_task finance "API/token/cost 检查 (metered cost + subscription usage) — $SLUG"
