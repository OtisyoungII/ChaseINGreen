# Trading-chart replay acceptance — 2026-11-22

## Implementation
Replay reuses CandleChartView, ChartViewport, ChartGeometry and QuantIndicatorEngine.
There is no added dependency or charting service. Original OHLC drives indicators even
when Heikin-Ashi display is selected. BB=20/2, MACD=12/26/9 (35-bar warmup), RSI=14
(15 bars), EMA=12/26/50/200 (period warmup). Indicators use prefix-only evidence.
The price chart and indicator panels use the same visible candle index range and
12/58-point horizontal padding. Price scale is right; historical time is below.
Pan/pinch/zoom/marker inspection are paused-only. No future prices set the price range.
Markers preserve retained prices/timestamps, active position lines change only with
reached state, and no HOLD markers are rendered. Recorded decisions remain usable
without candles, but the previous price-point fallback has been removed.

## Bounded evidence package
The existing read endpoint accepts at most 1000 reviewed OHLC bars for the exact
owner episode/symbol/venue, each with start/end/available_at, and a canonical hash.
Target window: at least 200 closed pre-entry bars for EMA200, complete through-position
bars, and a bounded post-exit window (e.g. 32 bars). This fits ordinary M15 episodes
within 1000 bars. Longer windows must explicitly remain incomplete or use separately
qualified aggregation; never silently discard intervening bars or invent OHLC.

Offline scripts/prepare_episode_replay.py accepts only an already exported <=2 MiB
window, emits reviewed=false, validates geometry/timestamps/size/duplicates and reports
warmup/gaps/position coverage. It does not query providers, read an active archive,
promote automatically or write production. Output retains separate recorded_chase,
recorded_owner and counterfactual tracks; narrative is not evidence. A human re-entry
is a new episode/risk decision, not an ADD. Reviewed promotion must preserve parent
identity/provenance and storage-pressure policy. The existing reader can consume its
normalized candles/hash after independent review. Human track rendering remains future
work; it is never merged into original Chase decisions. Counterfactuals require the
same reviewed frozen window and remain independently labeled.

## Actual availability
The production read-only inventory has zero trading_lab_replay_evidence_v1 packages,
zero research_promoted_lesson_v1 records and two BTCUSD shadow plans (latest 08:33:29
UTC Nov 22). This does not prove the owner's BTC sequence exists in Razer memory.
The existing Razer adapter archives deduplicated closed candles in WARM and material
transitions in EPISODE; its storage is not mounted on this Mac. No remote process,
retention, file or run was changed. After the run, export a bounded window plus explicit
human-action records if they exist, then assess coverage; missing human records stay
unavailable. Do not turn the owner's narrative into a backfilled action track.

The ETH SHORT episode 07473cdd-7e86-458d-949a-e8c348c28148 still lacks OHLC windows.
It therefore displays an explicit unavailable chart panel plus recorded decision replay,
not candles, indicator estimates, pre-entry or post-exit movement. No production data
collection/storage increase is part of this change. No backend deployment is needed.

## Verification
361 iOS model tests pass, including seven new chart/indicator tests and existing replay
clock/authorization/no-future-evidence tests. 21 backend replay/package tests pass.
Physical appearance requires owner acceptance because iPhone Mirroring reports iCloud
signed out. Installation does not by itself establish visual acceptance.
