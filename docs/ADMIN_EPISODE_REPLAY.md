# Admin episode replay

Read-only navigation: Admin → Auto Trader → Trading Lab → Episode History & Replay.
Existing episode details also link to Replay. Admin authorization is required on client
and server; Secret status alone grants no access. Nothing submits or manages trades.

## Evidence contract
GET /admin/auto-trader/trading-lab/episodes returns the latest 100 owner-scoped
Trading Lab episodes. GET /admin/auto-trader/trading-lab/{episode_id}/replay projects
existing immutable plans, material transitions and compact learning results.
The request neither queries providers nor writes PostgreSQL. Maximum 1500 transitions;
truncation is explicit and hides later scorecards. Response budget is 2 MiB.

Optional reviewed bounded evidence uses existing ledger child type
`trading_lab_replay_evidence_v1`, scoped to the exact parent episode/owner. This change
adds no ingestion endpoint or collector. Existing research promotion must independently
review evidence before supplying it; raw Razer research remains outside production.
The packet declares reviewed=true, symbol, venue, candles and evidence_hash. At most
1000 candles carry start/end/available_at and real OHLC. available_at must be at least
end. The SHA256 covers canonical JSON (sorted keys, compact separators) of symbol,
venue and normalized candles (UTC ISO timestamps, float OHLC, id=end). Invalid OHLC,
wrong scope, missing review or a different hash cannot be shown as candle evidence.

Optional counterfactuals (maximum three) declare unique id, COUNTERFACTUAL mode,
method/provenance, the same evidence_hash, timestamped frames/markers and compact
scorecard. These are reviewed precomputed results, never policies run by this viewer.
Original and replay results remain separately labeled. No comparison is fabricated.

## Playback integrity
1x advances one evidence point per second; timestamps display actual historical time.
Candles appear only at available_at. Frames and markers appear only when reached.
Reset clears visible future evidence; scrub is explicit. Historical gaps are not
interpolated. The chart uses sampled points when candles were not retained, never
synthetic OHLC. Later promoted candles permit post-exit playback. Scorecards appear
only at the end. Financial outcome is separate from recorded decision quality.
Unknown fees, indicators, judgments and lessons remain unavailable.

## Release
Backend read endpoints must be deployed before the new native screen can fetch them.
This feature branch does not modify/restart the Razer observer or enable execution.
No production episode inventory was queried for this UI implementation; actual
availability is determined by the owner-scoped history endpoint at runtime.
