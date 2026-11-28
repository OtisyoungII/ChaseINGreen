# Trader Workstation Pass 3 — implementation and audit

Date: November 27, 2026. Scope: canonical iOS, existing backend read-only source audit. Physical acceptance remains pending; compilation is not acceptance.

## Delivered changes

- Broker Management initializes from the requested provider. Previously `focusedProvider` was unused, the lane defaulted to Aqua, and every opening restored Aqua before loading Kraken. Provider-specific reads now run only for the selected lane; cached authenticated user validation runs separately. This removes an unrelated sequential dependency, not a measured claim about total latency.
- Kraken retains independent connection ID, name and Personal/Business registration, rename, synchronization and deletion flows. The credential label is API secret. Submitted values clear after successful registration and when leaving, changing lanes or backgrounding. A saved connection is no longer described as independently verified by the registration success message.
- Expanded room hides the parent pop control and supplies Back to collapse. The next native Back leaves the room. An edge-origin horizontal gesture collapses; the redundant interior Back is removed. Selection/room geometry/motion are preserved.
- Primary room account selection excludes explicitly terminal/historical statuses, using existing ledger classification plus expired/revoked/history states. Unknown status is not fabricated into either verified or failed. Historical records remain accessible through Universal/account records. No Auto Trader target is inferred or changed.
- Collapsible positions keep long lists from dominating the account workspace. Explicit Broker Management navigation reuses the existing panel, scoped to the room provider.
- Universal, room account positions and Kraken holdings now use `NormalizedPositionCard`. Kraken details also use it. Values come from the normalized row; no duplicate quantity × quote valuation. Spot holdings do not acquire a synthetic LONG label, stop or target. Unknown cost basis/P&L is unavailable. No deposit/withdrawal-derived performance calculation is introduced. Existing precision formatter preserves small quantities/prices; currency is explicit rather than assumed USD.
- Inspect/Analyze retains provider, canonical account, connection and native instrument context. Market identity does not grant execution authority. Existing Kraken Analyze callback is retained.
- Manage Trade navigation titles are inline. Kraken preview rows say unavailable here rather than operational. The existing manual ledger editing and supported Aqua protection flow are preserved, not rebuilt.
- Internal Kraken startup no longer awaits an unrelated Aqua health load. Carousel rotation remains presentation-only.
- Trade Home remains market-first and unchanged. No broad visual redesign was added.

## Latency evidence and limits

Source-confirmed unnecessary work: BrokerManagementPanel restored Aqua and then fetched Kraken for every entry; TradingWorkspaceView unconditionally fetched Aqua health during Kraken startup. Both dependencies removed. Retained room data remains visible during refresh. No provider sync was executed during this pass.

Actual authenticated physical before/after durations are **not measured**. Do not describe the source correction as a quantified production speedup. Physical Kraken loading and account switching still require review.

## Action audit (existing implementation, not live execution qualification)

| Action | Existing path / restriction | This pass |
|---|---|---|
| Stop loss | TradeActionSheet's live Aqua branch calls `/match-trader/positions/manage`, requires account/position IDs, preserves TP and checks response. Server applies current authorization and readback. Other ledger updates are not broker protection. | Preserved existing flow; not invoked. Shared inspection grants no authority. |
| Take profit / trailing / break-even | Match-Trader management router supports protection actions and independent position checks; static `ManageTradeCapabilities.aqua` alone does not establish account eligibility. | Not promoted to operational controls from a portfolio row. |
| Partial / reduce / full close | Match-Trader management path supports exact quantity/closure readback. TradeActionSheet manual reductions/closures are ledger operations and cannot be represented as broker fills without evidence. | Preserved; no new execution. |
| Kraken protection / entry / exit | Existing order endpoint requires internal access, live flag, qualified mutation release, explicit confirmation and owner-scoped connection. A spot asset balance is not an existing derivative trade. | Existing preview retained; no execution exposed by new card. |
| Kraken amend / cancel | Native endpoints use exact connection/order identity and the same server gates. ACK is not independently confirmed fill/cancellation. | No new button or bypass. |
| IBKR | Normalized account/position reads do not prove mutation authorization or live session eligibility. | Inspection/analysis only in shared card. |
| Robinhood | Crypto-only scope and existing Confirm Trade implementation remain separate. | Unchanged. |

No new stop/TP/trailing/break-even/partial/exit/amend/cancel capability was implemented. Live operation, current account authorization and provider result handling were not exercised with real orders. Manage Trade is **not certified complete** by this pass.

## Intelligence/reliability audit

- **AI levels:** PreTradeContextCard renders existing support/resistance fields. No level freshness, algorithm, role entitlement or backend response was changed. The inspected source establishes presentation, not fresh production levels. No new Gold/internal exposure was added.
- **Discovery / Trade Opportunity:** opportunity universe service has explicit fixed, watchlist and Kraken broker-universe adapters. Broker instrument availability and intelligence eligibility remain separate concepts; a provider catalog is not proof of analytical coverage. No scanner was duplicated. A current instrument-by-instrument production coverage comparison remains unverified.
- **Alerts:** ChaseINGreenApp requests notification permission and handles local notification categories. No `registerForRemoteNotifications` or APNs device-token registration was found in inspected iOS source. Backend `trader_notification_service` builds notifications/should_push metadata; that is not transport delivery. `/trade-alerts/` is authenticated on-demand evaluation with monitoring/owner-position checks. End-to-end background push is NOT proven; device registration/transport/configuration need a separate verified delivery investigation, not a claim that UI fixes restored alerts.
- **Journal:** backend trade_journal routes persist with commit and owner-filter both journal and linked trade lookups. This is real persistence architecture, not proof that a specific production entry has synchronized. No production journal was written. Generated summaries, shadow episodes and actual fills must retain their source classification; learning/training is not inferred from a rendered summary.
- **Replay:** AdminEpisodeReplayView selects candle chart when retained candles exist and RecordedDecisionTimeline when absent. Timeline uses `markers(at: cursor)` and resets inspection selection on cursor change. Missing candle evidence is explicitly labeled. No candles were synthesized; chronological physical acceptance and production episode completeness were not re-certified here. Separate execution-intelligence repairs remain separate.
- **Performance/cash flows:** card uses normalized open P/L only when explicitly available, never account balance change. Journal links owner-scoped trade IDs. Reconciliation should associate execution IDs/unique closure slices and fees with trades, and cash ledger IDs with deposits/withdrawals/transfers; transfer flows must be excluded from trading P/L and fee scope preserved. Missing cash-flow/valuation history cannot support a valid portfolio return. No new return computation is supplied in this pass.

## Verification and remaining acceptance

Focused suite: 65 tests passed, zero failures (room/access/workspace intent/context, Kraken connection selection/sync, formatting, presentation, authorization plus new account-state tests). These are unit tests, not real Personal/Business onboarding or provider mutations.

Device Debug build succeeded. Generic iOS Simulator build succeeded, including universal target compilation. Physical iPad layout has not been tested. Confirm Trade source was not modified.

Pending physical review: two-step Back/edge gesture, shared card hierarchy in Universal/Kraken/IBKR, switching account/provider with details open and dismissed, exact Analyze destination, long titles, real network timings, and scrolling. No live connection was added or credentials submitted for testing. No current account is designated execution-authorized by presentation policy.

## Changed files

- ChaseINGreen/Views/BatCave/BrokerRoomView.swift
- ChaseINGreen/Views/BatCave/BrokerManagementPanel.swift (scoped hunks only)
- ChaseINGreen/Views/BatCave/NormalizedPositionCard.swift (new shared UI)
- ChaseINGreen/Views/TradingWorkspaceView.swift (scoped hunks only)
- ChaseINGreen/Views/TradeActionSheet.swift
- ChaseINGreen/Models/TradePresentationPolicy.swift
- AuthorizationTests/WorkstationAccountPresentationTests.swift
- docs/TRADER_WORKSTATION_PASS3_20261127.md

Unrelated dirty work is preserved and excluded from staging. Backend changes/deployments: none. Orders submitted: 0. Broker mutations: 0. Execution authority unchanged. Free behavior unchanged. Existing internal route authorization preserved.

Physical installation: updated com.APLDEVO.ChaseINGreen 1.0 (14) in place on Otis's wired iPhone 15 Pro (UDID ending 0109001C), launch succeeded. No uninstall/reset. Deon's device untouched. Remote physical UI acceptance is not available while iPhone Mirroring reports iCloud signed out; owner review remains required.
