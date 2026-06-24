# Grasp — Hermes AI Team

A human-readable summary of the multi-agent team building Grasp. For the
operational rulebook agents must follow, see [AGENTS.md](AGENTS.md).

## 1. Company Architecture

```
Founder (you)
  └─ cos — Chief of Staff
       ├─ pm          — writes feature specs
       ├─ engineer    — writes code
       ├─ qa          — logic + UX + end-to-end scenario QA
       ├─ finance     — tracks API/token/cost risk
       ├─ growth      — marketing/positioning
       └─ ops         — release/TestFlight
```

No separate "product GM" layer — `cos` manages the Engineer Loop directly
since there's only one product (Grasp) right now.

## 2. Models in Use

| Role | Model | Notes |
|---|---|---|
| cos | DeepSeek v4-flash | escalates to real Claude Code CLI (`claude -p`) via the `claude-code` skill for tasks needing deep reasoning — uses the Claude subscription, not metered API |
| engineer | Codex (gpt-5.5) | native provider, billed through the ChatGPT/Codex subscription |
| pm, qa, finance, growth, ops | DeepSeek v4-flash | cheap, direct API billing |

## 3. Dev Flow (who manages whom)

1. **You → cos**: tell cos what you want, in plain language.
2. **cos → pm**: creates a kanban task; pm writes the spec + acceptance criteria.
3. **cos → engineer**: creates a task (parented to the spec) in an isolated
   git worktree/branch; engineer implements and commits, then stops (no PR yet).
4. **cos → qa + finance** (parallel): both check the same workspace. `qa`
   covers logic, UX, and scenario replay in one report; `finance` checks
   API/token/cost risk.
5. **cos judges**: reads both reports.
   - All pass → engineer opens a PR, stops, waits for you to merge.
   - Fails (1st–2nd time) → cos sends feedback back to engineer, retry.
   - Fails 3rd time → task blocked, escalated to you — no more auto-retry.
6. **After you merge** → cos creates an `ops` task to trigger TestFlight.

All of this runs automatically once you hand off a task — a background
gateway dispatcher (tied to `cos`) polls the kanban board every 60s and
spawns the right worker, so you don't drive each step by hand.
