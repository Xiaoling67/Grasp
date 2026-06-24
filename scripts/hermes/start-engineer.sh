#!/usr/bin/env bash
# Step 2 of the Engineer Loop (see AGENTS.md): hand the PM spec to Engineer
# in its own git worktree + branch, with a 3-attempt failure circuit breaker.
#
# Usage: start-engineer.sh <pm_task_id> <slug> "<任务标题>"
# Prints the created task id on stdout (full JSON goes to stderr).
set -euo pipefail

if [ "$#" -lt 3 ]; then
  echo "Usage: $0 <pm_task_id> <slug> \"<title>\"" >&2
  exit 1
fi

PM_TASK="$1"
SLUG="$2"
TITLE="$3"

JSON=$(hermes kanban --board grasp create "$TITLE" \
  --body "实现父任务（PM spec）里描述的功能和验收标准。只改这个任务必需的文件，不要顺手做其他改动。增量 commit，写清楚每次 commit 做了什么。完成后停下来——不要自己开 PR，也不要 merge。" \
  --assignee engineer \
  --parent "$PM_TASK" \
  --workspace worktree \
  --branch "wt/$SLUG" \
  --max-retries 3 \
  --created-by cos \
  --json)

echo "$JSON" >&2
echo "$JSON" | jq -r '.id'
