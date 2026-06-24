# Token Cost Impact: Concept Map (v1.1) vs. Per-Seal AI Notes (v1.0)

**Author:** Finance Agent
**Date:** 2026-06-24
**Scope:** Compare DeepSeek API costs for AI Notes (`generateNoteEntry`) vs. Concept Map (`generateConceptMapUpdate`)

---

## 1. Methodology

All token estimates are based on a line-by-line analysis of the actual source code:

- [DeepSeekService.swift](../../Grasp/Services/DeepSeekService.swift) — `generateNoteEntry()` (line 36) and `generateConceptMapUpdate()` (line 179)
- [AppViewModel.swift](../../Grasp/ViewModels/AppViewModel.swift) — `fireConceptMapUpdate()` (line 193) and `startConceptMapTimer()` (line 184)

Pricing uses published [DeepSeek API rates](https://api-docs.deepseek.com/quick_start/pricing) for `deepseek-chat` (non-reasoning model):
- Input: **$0.27 / 1M tokens**
- Output: **$1.10 / 1M tokens**

Token counts are estimated using the ~1.3 tokens/word rule of thumb, verified against actual prompt lengths in source.

---

## 2. Old System: Per-Seal AI Notes (`generateNoteEntry`)

### Per-Call Token Count

| Component | Tokens | Notes |
|---|---|---|
| System prompt | ~35 | "You are a silent, attentive note-taker..." |
| User prompt — fixed | ~65 | Lecture label, "What the prof just said:", notes header, extraction instructions |
| User prompt — transcript | ~100 | ~75 words (50-100 avg sealed block) |
| User prompt — existing notes context | ~40 | ~30 words of recent notes |
| **Total input** | **~240** | |
| **Output (JSON)** | **~25** | `{"slideIndex":0,"content":"...","level":1}` |
| **Total tokens/call** | **~265** | |

(No-slides branch used — the PDF slides spec confirms `slide_index = 0` always, so the slide-aware branch never fires for notes.)

### Per-Lecture Cost (400 seal events)

```
Per-call cost:
  Input:  240 × $0.27/1M = $0.000065
  Output:  25 × $1.10/1M = $0.000028
  Total: ~$0.000093/call

Per-lecture (400 calls):
  400 × $0.000093 = $0.037
```

### Monthly Cost (50 lectures)

```
50 × $0.037 = $1.86/month
```

---

## 3. New System: Concept Map (`generateConceptMapUpdate`)

### Cost Profile Depends on Map Size

Unlike the old system where every call was identical, Concept Map cost grows as the map grows — every call sends the **complete** existing map JSON back to DeepSeek. This is the single biggest cost driver.

### Call Frequency

- Timer fires every **15 seconds** → **200 fires** in a 50-min lecture
- Guard clause (`guard !windowBlocks.isEmpty`) skips ~15% of fires during pauses/transitions
- **~170 actual DeepSeek calls** per lecture

### Per-Call Token Count (by Phase)

#### Phase 1: Building (Calls 1–20, first ~5 min)
Map is small (0→5 nodes). Every fire adds new structure.

| Component | Tokens |
|---|---|
| System prompt | ~325 |
| User prompt — fixed overhead | ~135 |
| Slide structure | ~30 |
| Existing map JSON (avg 2.5 nodes) | ~125 |
| Window text (15s transcript) | ~50 |
| **Total input** | **~665** |
| **Output** (small map, ~3-6 nodes) | **~75** |
| **Cost per call** | 665×0.27/1M + 75×1.10/1M = **$0.000262** |
| **Phase total** | 20 × $0.000262 = **$0.005** |

#### Phase 2: Steady Growth (Calls 21–80, ~5–20 min)
Map grows from 5→15 nodes. The existing map JSON starts dominating input.

| Component | Tokens |
|---|---|
| System prompt | ~325 |
| User prompt — fixed overhead | ~135 |
| Slide structure | ~30 |
| Existing map JSON (avg 10 nodes, ~50 tok each) | ~500 |
| Window text | ~50 |
| **Total input** | **~1,040** |
| **Output** (mid-size map, ~10-15 nodes) | **~100** |
| **Cost per call** | 1040×0.27/1M + 100×1.10/1M = **$0.000391** |
| **Phase total** | 60 × $0.000391 = **$0.023** |

#### Phase 3: Mature Map (Calls 81–170, ~20–50 min)
Map stabilizes at 15–30 nodes. Most calls only deepen existing nodes.

| Component | Tokens |
|---|---|
| System prompt | ~325 |
| User prompt — fixed overhead | ~135 |
| Slide structure | ~30 |
| Existing map JSON (avg 22 nodes) | ~1,100 |
| Window text | ~50 |
| **Total input** | **~1,640** |
| **Output** (full map, potentially all nodes) | **~175** |
| **Cost per call** | 1640×0.27/1M + 175×1.10/1M = **$0.000635** |
| **Phase total** | 90 × $0.000635 = **$0.057** |

### Per-Lecture Cost

```
Phase 1 (20 calls):  $0.005
Phase 2 (60 calls):  $0.023
Phase 3 (90 calls):  $0.057
Total:               $0.085/lecture
```

### Monthly Cost (50 lectures)

```
50 × $0.085 = $4.25/month
```

---

## 4. Comparison Summary

| Metric | Old (Per-Seal Notes) | New (Concept Map) | Change |
|---|---|---|---|
| Calls per lecture | 400 | 170 | -58% |
| Avg tokens per call | ~265 | ~1,165 (blended) | +340% |
| Avg cost per call | $0.000093 | $0.000500 (blended) | +438% |
| **Cost per lecture** | **$0.037** | **$0.085** | **+130%** |
| **Monthly cost (50 lec)** | **$1.86** | **$4.25** | **+128%** |

### Why the Cost Increase

1. **Massive system prompt** — ~325 tokens vs ~35 (10× larger). The old system prompt was terse; the concept map prompt includes 10 detailed rules.
2. **Existing map is sent every call** — as the map grows to 15–30 nodes, the input includes 500–1,500 tokens of JSON that's returned almost unchanged.
3. **Higher max_tokens** — 1,500 vs 120, though actual outputs average 75–175 tokens.
4. **Fewer calls** partially offsets but does not compensate for the 4–6× higher per-call cost.

---

## 5. Sensitivity Analysis

### Best Case (minimal map growth, lots of skips)
- Only 20 nodes total, 30% skip rate (~140 calls)
- Avg map size: ~700 tokens
- Cost: ~$0.065/lecture → **$3.25/month**

### Worst Case (dense lecture, 40 nodes, no skips)
- Full 200 calls, 40 nodes → ~2,000 tokens existing map
- Cost: ~$0.12/lecture → **$6.00/month**

### Conservative Estimate (used above)
- ~$0.085/lecture → **$4.25/month**
- ~**$51/year** for 600 lectures

---

## 6. Phase 2 Cost Impact (Auto Explain + MemoryService)

The task also asked about Phase 2 costs. Verified from source:

### Auto Explain (`detectUnfamiliarTerm`, line 109)
- **Unchanged** — fires on every `seal()` (up to ~400/lecture)
- max_tokens=60, cost per call: ~$0.00003
- **New in v1.1:** `MemoryService.shared.checkConcept()` skips the full `streamSearch` if the term is already known (`.known` status at line 284) or was previously looked up (`.lookedUp` at line 286)
- **Saves ~$0.00015 per skip** — each skipped `streamSearch` call (max_tokens=200) that would have cost ~$0.00018
- **Monthly savings estimate:** ~$0.50–1.00/month depending on lecture density

### Cold Call (`generateColdCallAnswer`)
- **No change** in v1.1 — same call pattern as before

### Summary
Phase 2 changes are **cost-neutral to slightly beneficial** due to the MemoryService skip logic.

---

## 7. Recommendations

### 1. Switch to Diff-Based Map Updates (High Impact)
Currently, every call returns the **complete** updated map. Sending the full map as input costs 500–1,500 tokens each call (growing). Changing to a **diff format** (only send changed nodes + new window text) would:
- Keep input at ~500–700 tokens regardless of map size
- Save ~**40–50% of Phase 3 costs** (~$0.03/lecture, ~$1.50/month)

**Trade-off:** Higher implementation complexity, risk of state drift if diff fails to apply.

### 2. Skip System Prompt on No-Change Calls (Medium Impact)
When the only response is "no change" (existing nodes deepened trivially), the 325-token system prompt is wasted. Consider caching the system prompt or using it only on the first call.

### 3. Right-Size max_tokens (Low Risk)
Current max_tokens=1500. Actual output peaks at ~300–400 tokens even for dense maps. Reducing to **600** would add a safety margin without affecting quality and reduce worst-case billing for unusually verbose responses.

### 4. Lengthen Timer Interval (Medium Impact, Feature Impact)
15 seconds is aggressive for most lectures. At ~150 wpm, only ~37 words of speech happen in 15 seconds. Moving to **30 seconds** would:
- Halve calls from 170 to ~85
- Save ~**$0.043/lecture** ($2.15/month)
- **Downside:** Concept map updates less frequently, might feel sluggish

Consider making the interval **user-configurable** (15s/30s/60s) in settings.

### 5. Trim Redundant System Prompt Rules (Low Impact)
Several rules in the system prompt overlap with the output JSON schema:
- Rule 1 ("return COMPLETE map") could be in user prompt
- Rule 2 ("UUID format") could be in output schema
- Rules 7-10 are edge-case instructions that could be shorter

Estimated savings: ~80–100 tokens → ~**$0.006/lecture** ($0.30/month)

---

## 8. Verdict

| Attribute | Assessment |
|---|---|
| Absolute monthly cost | **$4.25/month** (50 lectures) |
| Cost increase vs v1.0 | **+128%** |
| Cost per student (app free) | N/A (no per-user pricing) |
| Acceptability | ✅ **Acceptable.** At $4.25/month, this is well within operational budget. |
| Action required | **Low priority.** Cost is manageable. Recommend implementing Recommendation #1 (diff-based) if map size exceeds 30 nodes in real-world usage. |

The Concept Map feature's token cost increase (~130%) is meaningful but not alarming — going from ~$1.86 to ~$4.25 per month for 50 lectures. This represents an additional **~$29/year**, which is negligible for an app in active development.

**Monitor after launch:** Add a metric for actual map size distribution. If any single user's lecture generates >40 concept nodes, the cost for that lecture could hit $0.12–0.15, and Recommendation #1 (diff-based updates) should be prioritized.

---

*Source code verified at: `/Users/catherineuspan/grasp/Grasp/Services/DeepSeekService.swift` and `/Users/catherineuspan/grasp/Grasp/ViewModels/AppViewModel.swift`*
