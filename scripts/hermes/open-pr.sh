#!/usr/bin/env bash
# Step 4 of the Engineer Loop (see AGENTS.md), pass branch: tell Engineer to
# open a PR from its branch and stop. cos only runs this after QA +
# Finance + its own review all pass.
#
# Usage: open-pr.sh <engineer_task_id> <slug>
set -euo pipefail

if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <engineer_task_id> <slug>" >&2
  exit 1
fi

ENG_TASK="$1"
SLUG="$2"

WS_PATH=$(hermes kanban --board grasp show "$ENG_TASK" --json | jq -r '.workspace_path // empty')

if [ -z "$WS_PATH" ]; then
  echo "engineer task $ENG_TASK has no resolved workspace_path yet" >&2
  exit 1
fi

JSON=$(hermes kanban --board grasp create "开 PR: $SLUG" \
  --body "QA 和 Finance 都通过了，cos 也审完了代码/架构/延迟。在分支 wt/$SLUG 上用 gh pr create 开一个 PR，标题和正文总结这次改动 + QA 结论。开完就停下——不要自己合并，等 Founder 在 GitHub 上 approve。" \
  --assignee engineer \
  --parent "$ENG_TASK" \
  --workspace "dir:$WS_PATH" \
  --created-by cos \
  --json)

echo "$JSON" >&2
echo "$JSON" | jq -r '.id'
