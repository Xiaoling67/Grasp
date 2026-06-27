# Grasp v1.1-r2 — Finance Quick Report

**Author:** Finance agent
**Date:** 2026-06-27
**Change from v1.1-r1:** Concept Map deleted, Notes switched to local-only (no AI cost).

## Per-lecture cost comparison

| Feature | v1.1-r1 | v1.1-r2 | Δ |
|---------|---------|---------|---|
| Deepgram Transcription | $0.215 | $0.215 | — |
| Concept Map | $0.083 | — | **−$0.083** |
| Auto Explain (detect + explain) | $0.061 | $0.061 | — |
| Search | ~$0.001 | ~$0.001 | — |
| Cold Call | ~$0.001 | ~$0.001 | — |
| **Standard mode total** | **~$0.361** | **~$0.278** | **−23%** |
| Translation (International add-on) | ~$0.007 | ~$0.007 | — |
| **International mode total** | **~$0.368** | **~$0.285** | **−23%** |

## Per-month (50 lectures, Standard)

| Metric | v1.1-r1 | v1.1-r2 |
|--------|---------|---------|
| Per lecture | $0.361 | **$0.278** |
| Per month (50 lectures) | $18.05 | **$13.90** |
| Per semester (~200 lectures) | $72.20 | **$55.60** |

**One-paragraph summary:** Removing the Concept Map feature (DeepSeek calls every 15s, ~190 calls/lecture at ~$0.083) brings per-lecture AI cost from $0.361 to **$0.278** in Standard mode — a 23% reduction. Deepgram transcription at $0.215/lecture now accounts for **77%** of total cost (up from 60%), making it the overwhelming driver. International mode tracks similarly ($0.285/lecture, −23%). Monthly cost drops from ~$18 to ~$14 at 50 lectures. Notes moving to local storage removes no prior AI cost (it was already cheap in v1.1-r1) but eliminates a future cost vector. No other changes to Auto Explain, Search, Cold Call, or Translation pricing assumptions.
