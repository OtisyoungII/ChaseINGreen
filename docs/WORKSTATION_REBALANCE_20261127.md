# Workstation rebalance — November 27, 2026

Baseline: canonical ChaseINGreen, feature/ibkr-machine-neutral-enrollment, HEAD 3866d2868ef019e73fd46af757d0414ba04e7255. Existing unrelated local modifications preserved. No backend change/deployment, provider reconnect, credential change or live order.

## Implemented

1. **Search-first instrument selection.** Shared native searchable browser replaces the complete native menu in the expanded broker and the first-40 strip in internal Kraken Trader OS. Exact, prefix and partial matching; search available label/native ID/canonical symbol/metadata; recent selections, owned and watchlist promotion; actual catalog class filters; lazy List rows; selected identity retained; Done/interactive keyboard dismissal. Watchlists reuse the existing owner-scoped coalesced read. Recent choices are memory-only for the account visit. No provider work occurs on room rotation. Search never rewrites the native instrument ID, merges products or grants trading authority.
2. **Kraken scope.** The current adapter used by these views returns spot pairs without per-instrument asset class. The UI labels that class unspecified and explicitly does not claim Kraken equity access. Asset-name search can only match names actually provided by metadata. No external product catalog was invented.
3. **Onboarding.** API Key / Private Key labels corrected, retaining the `apiSecret` wire field. Custom display name, Personal/Business contract, draft, timeout, secure entry, cancel/logout and keyboard fixes preserved.
4. **Privacy.** Snapshot cover now responds to background entry only and only while credentials exist in the draft. It is removed on foreground entry after expiry checking. Control Center/transient inactivity no longer deliberately activates a global cover. Both inputs remain secure. This does not promise system screenshot blocking; physical snapshot acceptance remains required.
5. **Retained truth.** Account evidence says last known/recent retained, never live merely because a GET completed. Account freshness re-evaluates periodically using existing source TTL policy. Position prices explicitly say last-known; accepted valuation provenance/freshness re-evaluates on the existing observation clock. Missing valuation timing is unverified. Refresh text accompanies retained account values. Existing in-flight/session guards and chart intent revisions remain intact.
6. **Financial presentation.** Reused MarketNumberFormat gains currency-aware values and local timestamps; tiny quantities support expanded decimals rather than default scientific fallback. Missing currency is identified rather than assumed USD. Missing values render an em dash with explanation, never zero. Stored values and arithmetic unchanged.
7. **Holding explanation.** Shared cards explain incomplete history, transfers/deposits, quantity mismatch and reconstructed basis through existing `basis_status`. Observation time is explicitly not purchase time. Market value does not imply cost basis. Technical provenance is expandable. Journal/Calendar access reuses the existing screen and clearly labels its all-account scope.
8. **Internal visual integration.** Graphite gradient background, translucent panels, compact workspace heading and retained-holdings terminology replace portions of the disconnected black presentation. Accepted broker room geometry and motion remain unchanged. No internal route was exposed to Gold/Free.
9. **Intelligence semantics.** Existing panel shows recorded-entry assessment separately from reported market direction, analysis time, and concise score explanation. Missing assessment no longer defaults to WAIT. No fabricated low/high thresholds, calibration, volume or probability introduced.

## Existing reconciliation audited and reused (not rewritten)

- `app/services/crypto/kraken_sync_service.py` already reads balances, open orders, executions and ledgers. TradesHistory and ledger pagination have bounded tests. Effective permissions/data completeness remain runtime facts, not inferred here.
- Existing cost reconstruction uses Decimal, USD-denominated fills including buy fees, with proportional weighted-average remaining acquisition cost after sells. It requires complete executions AND ledger, quantity reconciliation and no unresolved movement asset. This is not broker tax-lot authority. Incomplete history, non-USD denominations, quantity mismatch and transfers prevent a known total basis.
- `kraken_snapshot_service.accept_snapshot` verifies exact connection/account identity, rejects expired/out-of-order snapshots, checks duplicate position identity and retains normalized history by provider event ID. Snapshot membership is not an invented transaction.
- The iOS position contract exposes aggregate basis status and availability, not a reconciled list of known/unknown lots. There is no verified customer holding-detail contract for per-lot acquisition/disposition/fee/transfer history in this pass. Therefore no fake lot timeline or partial-known average was added. The existing backend must expose account-scoped, deduplicated events and explicit remaining known/unknown quantities before that UI can be operational.
- The 0.5 unknown + 0.25 confirmed acquisition example cannot truthfully become a completely known 0.75 holding. Existing fail-closed aggregate basis remains unavailable; a new partial-known ledger was NOT implemented.
- Journal is owner/trade scoped; Calendar and Aqua history behavior are unchanged. The new link does not claim complete cross-broker coverage. Additional broker/event/date reconciliation filters and a customer transaction-history endpoint remain incomplete.

## Verification

- 70 focused iOS tests passed, zero failures. Includes draft lifecycle, connection selection/sync, role access, account evidence, valuation freshness, ledger guards, intent isolation, formatting and four new search/format tests.
- 10,001-item catalog search test: under 0.1 seconds for two queries on this Mac. Not a physical keyboard latency claim.
- Device Debug build succeeded for canonical 1.0 (14), com.APLDEVO.ChaseINGreen.
- Existing backend test_kraken_truth_3.py, with in-memory SQLite: 9 passed, 1 failed. Failure: `test_current_activity_excludes_orphan_and_disconnected_without_mutating_history` fixture lacks `ibkr_account_states`. No backend source changed; no production database touched. Passing tests include fees/partial disposal, incomplete history rejection and history pagination.
- No real registration, sync, history import, broker mutation, deposit, withdrawal or trade was made to test these screens.

## Honest remaining limits

Physical search/navigation/privacy/clipboard acceptance is pending. No proof is claimed of current broker histories or cost basis for the owner's actual balances. Old network responses remain guarded by existing session/in-flight/intent controls; this is not certification of every screen in the app. No new reconciliation engine, partial-known lot accounting, universal event UI or calibrated risk categories were built. Bull/bear artwork was deferred in favor of correctness; no unsupported new graphic or direction inference was introduced. Full visual migration of every legacy tool remains incomplete.

Orders: 0. Broker mutations: 0. Execution authorization unchanged. Confirm Trade unchanged. Free unchanged. Business connection untouched. Unrelated work preserved.
