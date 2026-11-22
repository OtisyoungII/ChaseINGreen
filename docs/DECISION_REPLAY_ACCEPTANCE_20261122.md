# Decision Replay fallback acceptance repair

Physical acceptance of the earlier Replay UI failed. A 250-point unavailable-content
panel occupied the primary surface of every episode without promoted OHLC, preceding
the controls and diagnosis. Controls existed beneath it, but the product presented a
blocked chart instead of a usable recorded replay. That was not successful acceptance.

The same screen now explicitly routes:
- no OHLC + retained frames/markers → DECISION REPLAY, controls first, compact secondary
  candle notice, progressive recorded-action narrative and timestamped diagnosis;
- reviewed OHLC → FULL MARKET REPLAY, preserving the existing candle renderer/indicators.

Timeline actions are only revealed at their recorded time. Tapping a reached action
opens its at-time evidence. Three recent reached actions stay prominent; older reached
transitions remain inspectable below. No interpolated prices or synthetic candles.
Scorecard remains gated to the end of playback. Missing indicator warmup or post-exit
candles never disables unrelated decision evidence.

Validation: 365 Swift tests passed, including production-retained transition excerpts
(read-only query, not authenticated full endpoint response) from:
- ETH SHORT 07473cdd-7e86-458d-949a-e8c348c28148
- BCH LONG 8759ef9e-39c7-4375-afea-6ec96a67ab45
- LTC LONG f7e6fa96-2317-462a-9069-c88e0a405aa1
The excerpt test validates decoding, no-OHLC availability, progression through recorded
exit, reset and zero fabricated candles. Full-market/future-hiding/warmup coverage uses
fixtures. Physical full-market acceptance is not claimed.

No backend deployment, storage-breaker change, BTC package promotion, Razer access,
observer change or broker operation. Owner reports the real 79-candle BTC package is
prepared on Razer but not promoted; this task leaves that state alone.

Canonical signed Debug build succeeded. In-place installation targets only Otis's
00008130-000158A20109001C iPhone 15 Pro, com.APLDEVO.ChaseINGreen, 1.0 (14).
READY_FOR_OWNER_PHYSICAL_ACCEPTANCE is the boundary, not IMPLEMENTED_AND_WORKING.
