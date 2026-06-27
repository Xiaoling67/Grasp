# Grasp v1.1 — Finance Report

**Author:** Finance agent  
**Date:** 2026-06-27  
**Scope:** Token/cost per 50-minute lecture, all v1.1 features  
**Pricing sources (USD, as of 2026-06):**

| Service | Pricing | Model |
|---------|---------|-------|
| Deepgram Nova-3 | $0.0043/min | WebSocket streaming |
| DeepSeek-chat input | $0.27/1M tokens | deepseek-chat (V2/V3) |
| DeepSeek-chat output | $1.10/1M tokens | deepseek-chat (V2/V3) |
| Qwen-MT Flash input | ~$0.0006/1M tokens | qwen-mt-flash (DashScope US) |
| Qwen-MT Flash output | ~$0.0006/1M tokens | qwen-mt-flash (DashScope US) |

> DeepSeek offers cache-hit pricing ($0.14/M input) — **not factored** below. All calculations use standard uncached input pricing ($0.27/M). Real costs could be ~30-50% lower if prompt patterns produce cache hits.

---

## 1. Per-lecture cost — Standard mode

### 1a. Deepgram Transcription
- Rate: $0.0043/min × 50 min
- **$0.215** (exact, per Deepgram published pricing)

### 1b. Concept Map (DeepSeek, every 15s)
- Fires: `Timer.scheduledTimer(withTimeInterval: 15.0, repeats: true)`  
  → 50 min × 60 / 15 = 200 firings, ~190 with actual transcript data
- **Per call — typical tokens:**
  - System prompt: ~450 tokens (10 rules, JSON schema, UUID instructions)
  - User prompt: ~350 tokens average (subject + slide structure + existing map JSON + 15s transcript window)
  - **Input total: ~800 tokens avg** (starts ~600, grows to ~1,200+ as the concept map expands)
  - **Output: ~200 tokens avg** (returns COMPLETE updated map; starts ~80 tokens, grows to ~600+ by late lecture; averaged across all calls)
- `max_tokens: 1500`

| Item | Tokens per lecture | Cost |
|------|-------------------|------|
| Input | 190 × 800 = 152,000 | $0.041 |
| Output | 190 × 200 = 38,000 | $0.042 |
| **Subtotal** | | **$0.083** |

### 1c. Auto Explain (DeepSeek, per sealed block)
- ~400 sealed blocks/lecture (Deepgram UtteranceEnd events, ~2s silence detection)
- **Two-tier architecture** (confirmed in `AppViewModel.autoExplain()`):

**Tier 1 — Detection (every block, ~400 calls)**
- `detectUnfamiliarTerm()` — non-streaming, `max_tokens: 60`
- Input: ~180 tokens (system ~18 + prompt ~160)
- Output: ~30 tokens (JSON `{"term": "...", "confidence": 0.82}`)
- ~30% of blocks (~120) return `term: null` → no further action
- ~70% (~280) return a valid term with confidence > 0.65

**Tier 2 — Knowledge Profile routing (280 blocks with term found)**
- `.known` (~30% of 280 = **84**) → skip, **no extra API call** (saves ~30% of Tier 2 calls vs. v1.0)
- `.lookedUp` (~10% of 280 = **28**) → inline reminder from local data, **no extra API call**
- `.neverSeen` / `.preventive` / `.dismissed` (~60% of 280 = **168**) → full explanation via `streamSearch()`

**Tier 2b — Full explanation (168 calls)**
- `streamSearch()` — streaming, `max_tokens: 200`
- Input: ~250 tokens (system ~20 + prompt with 10 context blocks + query + known terms injection)
- Output: ~100 tokens (definition | analogy, two sentences)
- Plus in-memory dedup (`recentlyExplained`, max 60) prevents re-explaining same term within a lecture

| Item | Tokens per lecture | Cost |
|------|-------------------|------|
| Detection input | 400 × 180 = 72,000 | $0.019 |
| Detection output | 400 × 30 = 12,000 | $0.013 |
| Explanation input | 168 × 250 = 42,000 | $0.011 |
| Explanation output | 168 × 100 = 16,800 | $0.018 |
| **Subtotal** | | **$0.061** |

### 1d. Search (DeepSeek, user-driven)
- ~5 searches per lecture (user-initiated via selection popup)
- `streamSearch()` — streaming, `max_tokens: 200`
- Per call: input ~200 tokens (system + prompt + 10 context blocks + query + known terms), output ~100 tokens
- Cached per session (in-memory `searchCache`) — repeat lookups of same term cost $0

| Item | Tokens per lecture | Cost |
|------|-------------------|------|
| Input | 5 × 200 = 1,000 | $0.0003 |
| Output | 5 × 100 = 500 | $0.0006 |
| **Subtotal** | | **~$0.001** |

### 1e. Cold Call (DeepSeek)
- ~3 detections per lecture (90s cooldown between detections)
- `generateColdCallAnswer()` — streaming, `max_tokens: 300`
- Per call: input ~500 tokens (system + question + 15 context blocks + slides + 10 notes + subject), output ~150 tokens
- Context is heavy: last 15 blocks + slides + last 10 notes + Knowledge Profile

| Item | Tokens per lecture | Cost |
|------|-------------------|------|
| Input | 3 × 500 = 1,500 | $0.0004 |
| Output | 3 × 150 = 450 | $0.0005 |
| **Subtotal** | | **~$0.001** |

### Standard mode total

| Feature | Cost per lecture | % of total |
|---------|-----------------|-----------|
| Deepgram Transcription | $0.215 | 59.6% |
| Concept Map | $0.083 | 23.0% |
| Auto Explain | $0.061 | 16.9% |
| Search | ~$0.001 | 0.3% |
| Cold Call | ~$0.001 | 0.3% |
| **Total** | **~$0.361** | 100% |

---

## 2. Per-lecture cost — International mode

Adds per-seal translation on top of Standard mode.

### 2a. Translation (Qwen-MT Flash + DeepSeek fallback)
- ~400 sealed blocks/lecture, each gets async translation
- **Qwen-MT Flash** (primary): input ~120 tokens (English block text), output ~150 tokens (Chinese translation)
  - DashScope US pricing: ~$0.0006/1M tokens
  - 400 × (120 + 150) = 108,000 tokens → **~$0.000065**
- **DeepSeek fallback** (when Qwen fails; `translation_options` parameter may cause non-standard requests to fail; estimate 5% fallback rate = ~20 calls)
  - `max_tokens: 1000`, but actual output for ~100-word block = ~200 tokens
  - Per call: input ~500 tokens (system ~50 + instructions + text), output ~200 tokens
  - 20 × (500 + 200) = 14,000 tokens → $0.0027 in + $0.0044 out = **~$0.007**

| Item | Tokens per lecture | Cost |
|------|-------------------|------|
| Qwen-MT Flash (400 calls) | 108,000 | ~$0.0001 |
| DeepSeek fallback (20 calls) | 14,000 | ~$0.007 |
| **Subtotal** | | **~$0.007** |

### International mode total

| Feature | Cost per lecture |
|---------|-----------------|
| Standard mode total | $0.361 |
| Translation (Intl) | $0.007 |
| **Total** | **~$0.368** |

> Translation cost is negligible in International mode because Qwen-MT Flash is ~450× cheaper than DeepSeek per token. Even with 100% DeepSeek fallback (which would cost ~$0.14/lecture), it would still be the cheapest feature after Search/Cold Call.

---

## 3. Cost per month (50 lectures, Standard mode)

| Frequency | Cost |
|-----------|------|
| Per lecture | $0.361 |
| Per day (1 lecture) | $0.361 |
| Per week (5 lectures) | $1.81 |
| Per month (50 lectures, ~12/week) | **$18.05** |
| Per semester (~200 lectures) | **$72.20** |

For International mode: ~$18.40/month (difference of $0.35/month).

---

## 4. Biggest cost drivers

| Rank | Driver | Cost/lecture | % | Notes |
|------|--------|-------------|---|-------|
| 1 | **Deepgram transcription** | $0.215 | 59.6% | Fixed cost per minute of lecture time. |
| 2 | **Concept Map** | $0.083 | 23.0% | Grows with lecture duration. Output dominates because the COMPLETE map is returned every 15s. Output cost ~1.5× input cost even though input is 4× larger by volume. |
| 3 | **Auto Explain - detection** | $0.032 | 8.9% | 400 small calls per lecture. Individual calls are cheap (~$0.00008 each) but volume adds up. |
| 4 | **Auto Explain - explanations** | $0.029 | 8.0% | 168 streaming explanation calls. Knowledge Profile's 30% skip rate already saves ~$0.012/lecture vs v1.0. |
| 5 | **Cold Call + Search** | ~$0.002 | 0.6% | Negligible — low frequency, small outputs. |

### Key insight

**Transcription is the dominant cost** at ~60%, and it's entirely fixed — you can't optimize it without switching to a cheaper provider (e.g., Whisper via local inference would be free but requires compute).

**The Knowledge Profile skip** (Auto Explain → `.known` → skip) already saves ~$0.012/lecture vs v1.0. If the profile expands over time (student learns more terms → more `.known` matches), savings grow with usage.

---

## 5. Recommendations to reduce cost

### High impact
1. **Concept Map: return diff, not full map** — Currently returns the complete updated nodes array every 15s (`max_tokens: 1500`). A diff-based approach (only new/changed nodes) would reduce output tokens by ~60%, saving ~$0.050/lecture ($2.50/month).
2. **Batch concept map to 30s** — Doubling the interval from 15s to 30s halves the number of calls from 190 to ~95. Saves ~$0.042/lecture ($2.10/month). Risk: students see less responsive concept map updates.

### Medium impact
3. **Increase concept map `recentlyExplained` set** — Currently capped at 60 terms in-memory. Expanding it (or persisting lecture-to-lecture via Knowledge Profile) would reduce redundant Auto Explain explanations across lectures. Potential savings: ~$0.005-0.010/lecture after the first few lectures.
4. **Auto Explain detection: skip `known` and `lookedUp` blocks before API call** — Currently, `detectUnfamiliarTerm()` is called for EVERY sealed block regardless of Knowledge Profile. Moving the Knowledge Profile check *before* the detection call would save those 400 detection calls entirely for ~30% known blocks + ~10% lookedUp blocks. Saves ~$0.016/lecture in detection costs.

### Low impact
5. **Increase cold call cooldown** — 90s → 120s reduces per-lecture detections from ~3 to ~2. Saves ~$0.0003/lecture. Not worth the UX regression.
6. **Cache concept map responses** — If the same 15s window produces no new concepts, the system prompt + context tokens are wasted. Adding a "no-change" detection (hash of input text) before calling DeepSeek could save ~10% of concept map calls (~$0.008/lecture).

### Summary of potential savings

| Package | Monthly saving (50 lectures) | Effort | Risk |
|---------|---------------------------|--------|------|
| Diff-based concept map | ~$2.50 | Medium | Correctness |
| 30s concept map interval | ~$2.10 | Low | UX responsiveness |
| Pre-check Knowledge Profile | ~$0.80 | Low | None |
| No-change concept map skip | ~$0.40 | Low | None |
| Session-to-session profile | ~$0.25-0.50 | Medium | None |
| **Max possible** | **~$6.00/month** | — | — |

> With all optimizations, per-lecture cost could drop to ~$0.24 (Standard) or ~$0.25 (International). Current $18.05/month at 50 lectures could be reduced to ~$12/month.

---

## Appendix: Source code references

| Feature | Code location | Key parameters |
|---------|-------------|----------------|
| Concept Map | `DeepSeekService.generateConceptMapUpdate()` | System: ~450 tok, User: ~350+ tok, `max_tokens: 1500` |
| Detection | `DeepSeekService.detectUnfamiliarTerm()` | System: ~18 tok, User: ~160 tok, `max_tokens: 60` |
| Explanation / Search | `DeepSeekService.streamSearch()` | System: ~20 tok, User: ~230 tok, `max_tokens: 200` |
| Cold Call | `DeepSeekService.generateColdCallAnswer()` | System: ~30 tok, User: ~470 tok, `max_tokens: 300` |
| Translation | `QwenTranslationService.translate()` (Qwen primary → DeepSeek fallback) | Qwen: single-msg ~120+150 tok; DeepSeek: system ~50 + user ~450 tok, `max_tokens: 1000` |
| Timer / routing | `AppViewModel.swift` lines 287-330 (auto-explain), 184-240 (concept map timer) | 15s timer, 90s CC cooldown |
