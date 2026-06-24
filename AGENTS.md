# Grasp — Hermes Multi-Agent 团队

这个仓库由一组 Hermes profile 协作开发。任何在这个仓库里工作的 profile（无论是被
kanban 任务派发，还是被直接 `cd` 进来跑），都要遵守下面的指挥链和硬规则。

## 指挥链

```
Founder（人类，Hermes 终端）
  └─ cos          Chief of Staff + Grasp App 的 GM（DeepSeek，重活委托 claude-code）
                  — Founder 的唯一直接对话入口，同时编排下面的 Engineer Loop
       ├─ pm          产品经理（DeepSeek）— 写 feature spec + 验收标准
       ├─ engineer    工程师（Codex）— 写 Swift 实现
       ├─ qa          QA / 逻辑 + UX + 场景回放（DeepSeek API）
       ├─ finance     API / token / cost 统计（DeepSeek API）
       ├─ growth      增长（DeepSeek）
       └─ ops         发布 / TestFlight（DeepSeek）
```

只有 Grasp 一个产品时不设单独的"产品 GM"层，`cos` 直接兼任。如果未来同时开发多个产品，
再考虑给每个产品加一个独立的 GM profile。

所有任务都在 `grasp` 这个 kanban board 上（`hermes kanban boards switch grasp`）。
默认 workdir 就是这个仓库。

## 硬规则（所有 profile 必须遵守）

1. **只改任务需要的文件。** 不做 drive-by 重构、不顺手改格式、不做"既然在这里就……"
   式的清理。一个任务的 diff 应该让人一眼看出改动和任务描述的对应关系。
2. **Engineer 的每个任务都在独立的 git worktree + 独立分支上**（`wt/<slug>`），
   绝不直接在 `main` 上改动。
3. **频繁、清晰地 commit。** 每个 kanban 任务在它自己分支上的 git log 应该完整、
   可读、可以单独 revert——这是"出问题能恢复"的唯一保障。
4. **任何 profile 都不自己 push 到 main、不自己 merge PR。** Engineer 在 QA 通过后
   开一个 PR 就停下，剩下的交给 Founder 人工 approve + merge。
5. 同一个任务连续失败 / 被 QA 打回 3 次后停止自动重试，把任务标记为
   blocked 并写清楚原因，等 Founder 在 Hermes 终端里处理（暂未接 Telegram，
   所以不会主动推送通知——Founder 需要自己跑 `hermes kanban --board grasp diagnostics`
   或 `hermes kanban --board grasp list` 来看）。

## Engineer Loop（每个 feature / fix 都走这一套）

辅助脚本在 `scripts/hermes/`，处理最容易出错的 flag 组合；`cos` 仍然要自己用
`hermes kanban` 系列命令读取任务状态、做通过/重试的判断。

0. **cos 判断改动量级**
   Founder 提出需求后，`cos` 先用 `claude-code` skill（委托给真正的 Claude Code）判断
   这是不是"重大产品改动"——这个判断本身不能让 DeepSeek 凭感觉拿主意。判断结果决定
   下一步 pm 写 spec 时是否也要用 claude-code。

1. **PM 写 spec**
   ```
   scripts/hermes/new-feature.sh "<feature 标题>" "<Founder 的原始需求描述>"
   ```
   创建一个分配给 `pm` 的任务，输出 `pm_task_id`。pm 把 spec + 验收标准写成
   任务 comment。**全新 feature 的第一版 spec，或对已有功能的重大改动**，pm 强制用
   `claude-code` skill 写（走 Founder 的 Claude Code 订阅）；常规小改动/bug fix 的
   spec，DeepSeek 自己写就行。

2. **Engineer 实现**
   ```
   scripts/hermes/start-engineer.sh <pm_task_id> <slug> "<任务标题>"
   ```
   创建一个 `--parent <pm_task_id>` 的 engineer 任务，worktree workspace，
   分支 `wt/<slug>`，`--max-retries 3`。Engineer 通过 parent 关系自动拿到
   PM 的 spec 作为上下文，实现完成后 commit 并停下（不开 PR）。

3. **QA + Finance 并行核查**
   ```
   scripts/hermes/qa-check.sh <engineer_task_id> <slug>
   ```
   读取 engineer 任务实际落地的 workspace 路径，创建 2 个子任务（qa /
   finance），`--workspace dir:<同一个路径>`，让它们检查同一份代码而不是各自的
   scratch 沙盒。`qa` 必须在同一份报告里覆盖逻辑 / UX / 场景回放三条线。

4. **cos 裁决**
   `cos` 用 `hermes kanban --board grasp show <task_id>` 读 QA/Finance
   任务的结论，自己做代码评审 + 架构/延迟检查——**这一步强制用 `claude-code` skill**
   委托给真正的 Claude Code 做评审，不管任务大小，因为这是放行前的最后一道关。
   结合 Finance 的 cost 数字判断：
   - **全部通过** → 跑 `scripts/hermes/open-pr.sh <engineer_task_id>`，
     Engineer 在它的分支上开 PR，停下来等 Founder。
   - **有不通过，且这是这个 engineer 任务第 1-2 次被打回** → 用
     `hermes kanban --board grasp comment <engineer_task_id> "<QA 发现的问题>"`
     写清楚问题，再用
     `hermes kanban --board grasp promote <engineer_task_id> "QA 打回第 N 次，继续修"`
     让 Engineer 在同一个分支上继续修，回到第 3 步。
   - **第 3 次仍不通过** →
     `hermes kanban --board grasp block <engineer_task_id> "QA 连续 3 次不通过：<原因>"`，
     停止自动重试，等 Founder 处理。

5. **Founder approve + merge 之后**
   `cos` 创建一个 `ops` 任务触发 TestFlight：
   ```
   hermes kanban --board grasp create "Trigger TestFlight: <feature>" \
     --assignee ops --created-by cos
   ```

## 谁来跑这套流程

`cos` 是这个 loop 的编排者。Founder 在 Hermes 终端跟 `cos` 说一句话
（比如"我想加一个 XX 功能"），cos 负责依次跑上面 1-5 步，并在每一步之间
读任务状态做判断。
