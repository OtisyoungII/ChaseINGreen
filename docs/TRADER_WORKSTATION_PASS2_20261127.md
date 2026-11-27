# Functionalization Pass 2 — intent-driven broker workspace

Baselines: c058416 (accepted interaction), eccdd10 (functionalization 1).
No backend changes, execution changes, credentials, orders or broker mutations.

## Environment
Moved the existing environment behind the entire root view, outside the safe-area
GeometryReader. Navigation chrome remains transparent with a dark color scheme;
Back/title/Universal remain system safe-area controls. Stage geometry, transforms,
rotation, palette and expansion are unchanged. Physical appearance requires owner review.

## Intent and request map
1. Room: existing lightweight normalized account/position GETs, retained immediately.
   Seat rotation only changes presentation. NO auth, sync, instrument, chart,
   timeframe or execution-preparation requests occur from rotation.
2. Enter: asynchronous existing normalized-read preparation (30-second foreground
   throttle, in-flight guard); animation does not await it.
3. Workspace visible: iOS scroll visibility (10%) arms one account-specific preparation.
   Instantiating the off-screen section does not start a catalog read.
4. Instrument selected: retained provider mechanics/capability context; no candle fetch.
5. Timeframe selected: one existing candle request, with provider, native account,
   connection, instrument and timeframe. No all-timeframe loop or adjacent prefetch.

BrokerWorkspaceIntent formalizes layers. BrokerTradingSurface owns one account identity;
changing account recreates only that deeper state. Async work checks task cancellation,
auth session generation, exact request key and intent revision. Candle cache is bounded
at eight series per surface/visit; API's existing owner/account-scoped cache also applies.
No polling. DEBUG-only intent logs contain layer/work descriptions, no credentials.

## Data paths and honest capability boundaries
- Kraken: existing GET instrument catalog. **Venue products**, not proof of account
  trading permission. Base/quote and provider decimal precision displayed.
- Aqua: existing account-specific instrument adapter/cache. Response account must match
  requested account exactly. Group, minimum volume, volume step, session/tradable flags
  shown only if supplied. No futures-contract inference. Catalog age unavailable is
  explicit. This existing read endpoint uses POST; no new synchronization/login flow.
- Robinhood Crypto: existing retained GET connection truth, exact connection/canonical
  account match. Reuses existing RH snapshot decoder, extended with optional retained
  pairs. Partial/malformed optional product metadata cannot break account decoding.
  Crypto API tradable flag, supplied minimum/increments and retained order history shown.
  No reconnect or live provider refresh. No equity/futures claims.
- IBKR/other supported account records: instruments observed in exact-account normalized
  positions only, explicitly **not a complete tradable universe**. Contract mechanics and
  execution eligibility unavailable. Public IBKR remains information/monitoring.
- Manual: no provider universe or API execution claimed.

Market data source labels come from returned candles. Empty/error evidence is unavailable,
never synthetic. Market data does not establish execution/protection authority.

## Orders, fills, settings, Replay
Robinhood retained order history is capped at 20 displayed rows, with total retained-row
count and explicit warning that it is not a live open-order count. Other broker order/fill
contracts are not wired in this bounded pass and remain unavailable, not empty.
Robinhood settings/trade review reuses the existing view with an optional initial connection
ID verified against the owner's returned connection roster. It does not auto-pick another
connection if that scope is missing. Existing Confirm Trade implementation is untouched.
No customer-authorized account/instrument Replay contract was established; no Gold route
was added into Admin Replay. No competing old Batcave screen was restored.

## Roles / safety
Free unchanged; customer room and deep preparation require existing Gold/Secret/Admin
capabilities. Secret/Admin internal routes remain under their existing policy. Gold gains
no Auto Trader, Trading Lab, research, provider operations or diagnostics authority.
Backend authorization continues independently. No submission/preview API calls added.

## Verification
25 focused tests: room permissions, evidence/selection rules, internal authorization,
Dashboard concrete-boundary regression, four intent-state tests and one structural wiring
regression. Covers 100 rotations with no work, explicit layers, invalidation on rapid
account/instrument changes, retained context, and request calls excluded from rotation.
Canonical device and simulator build/install results reported in completion message.
Physical gesture/visual acceptance is not inferred from tests or installation.

## Next gaps
- Physical full-screen and scroll-intent acceptance on owner device.
- Account-specific normalized fills/order DTOs beyond retained Robinhood history.
- Account-authorized Replay routing and additional customer-scoped broker settings.
- Complete IBKR account instrument discovery where a proven existing contract allows it.

Final build verification: canonical Debug iPhone build PASS; generic iOS Simulator
build PASS (iPhone/iPad target support retained). Canonical 1.0 (14) installed in place
and launched on Otis iPhone 15 Pro, bundle com.APLDEVO.ChaseINGreen. No uninstall/reset.
Mac iPhone Mirroring still reports iCloud Signed Out. Full-screen appearance, scrolling
and physical lazy-loading interaction require owner acceptance; not claimed as verified.
