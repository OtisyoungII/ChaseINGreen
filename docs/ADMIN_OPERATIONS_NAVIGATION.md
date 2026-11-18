# Admin operations navigation — 2026-11-17

## Scope and result

In-place canonical iOS presentation correction. No new target, app, bundle, provider integration or execution authority. Business enrollment is paused. No real request was approved/rejected, no device installation was performed, and no backend was deployed by this work.

Admin Home now navigates to Overview, Brokers, Trading Operations, Learning and System. Pending Actions is prominent and reports unavailable rather than inventing an empty queue when its service is absent. User search and tier/activity filters render 30 compact rows at a time. Existing detail screens retain account administration and truthful activity semantics.

Broker Command Center separates Personal/Business IBKR and routes to individual native-account identities, qualified account metrics and positions. Aqua official intake is under Aqua connection management. Account totals never sum unlike quantities; missing currency and missing values remain explicit. Account safety/freshness and protection remain visible; canonical IDs and raw timestamps are drill-down evidence.

Auto Trader shows locked execution, disabled new risk, account health/position counts, Pending Actions, compact broker groups, watching counts and recent broker events. Cached reads refresh every 30 seconds only while visible/active. This does not start provider observation. Markets use Active/Attention/All filters, with disabled markets off the primary screen. Selected Trade Viewer is a destination, not an empty primary-screen panel. Existing audit intents remain behind a disclosure and confirmation, and do not execute.

Evidence Log reads bounded 30-record pages. Loaded-page filters cover broker, account, symbol, event type, freshness and date window. Next replaces the page rather than creating an unbounded scroll. Repeated same-account/type/time/freshness events group together; raw records remain available on drill-down. Filters are explicitly page-local, not a claim to search all historical records server-side. Earlier complete source/decision/watch-preference diagnostics are preserved in AdvancedAdminOperationsView.

ML Learning Lab and Trade Intelligence have explicit Real observations / Demo-Shadow selection. Old-mode content is cleared and request generation prevents a late response publishing under the wrong mode. Observation records are not described as training runs. Detail groups reduce primary metric overload. Existing training controls/authority are not enabled or invoked by this task.

## Related backend patch (not deployed)

Existing owner-only IBKR enrollment authorization guards two additions:
- GET /ibkr/enrollment/requests: up to 50 unexpired pending requests, safe requested machine/name/ownership, duplicate warning, expiry and review code. No claim proof, token hash or credential serialization.
- POST /ibkr/enrollment/requests/{code}/reject: row-locked pending-to-rejected transition; expired/terminal/other-owner records fail closed. No connection or broker mutation.

Existing approve/redeem behavior is reused. Labels are explicitly requester-supplied, not verified account identity. Approve/Reject requires an account-named confirmation; uncertain results require refresh, never automatic retry. Pending request listing must be deployed before the owner can test automatic discovery in production. No schema migration.

## Validation and limitations

- Swift package: 317 passed, zero failures.
- Backend focused enrollment/lifecycle/integration: 31 passed, one skipped.
- Backend broker truth/pipeline/presentation regressions: 77 passed, zero failures.
- Canonical iOS Debug build and deep/strict signature verification passed.
- Both repositories: git diff --check passed.
- No icon, public Dashboard, manual-account removal, observer, Aqua credential or execution code changed.
- Layout uses native navigation/List, adaptive rows, Dynamic Type and no fixed phone-width assumptions. Actual iPhone/iPad rendering and the owner's 5–10 second scanability goal still require visual acceptance; compilation is not visual acceptance.
- No claim of a pending production request count, physical acceptance, or live enrollment completion.

## Owner acceptance after coordinated release/build installation

1. Admin exposes Pending Actions without searching through unrelated screens.
2. Review shows requested Razer/Business identity, duplicate warning and expiration; do not approve until separately instructed.
3. Brokers → IBKR distinguishes …1141 and …5747, plus Business only if actually represented by qualified data.
4. Auto Trader clearly shows execution locked, new risk disabled, current/stale evidence, positions and markets.
5. Evidence is accessible without dominating primary screens; Real/Demo data never crosses mode labels.

Business enrollment must not resume automatically after this UI work.
