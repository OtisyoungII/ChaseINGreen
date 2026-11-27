# Trader Workstation functionalization — Pass 1

Accepted interaction baseline: `c058416a4229e18f855787f790c7f727093f393a`.
No room geometry, broker positioning, rotation, surface expansion, return animation,
orb treatment or provider palette changed. Toolbar destinations are outside that geometry.
No backend or broker integration changes.

## Concrete inventory
Counts below are **component definitions**, not repeated account/position instances.
Four provider surfaces and their four decorative headlines count separately. A row
with several displayed facts remains one explicitly named component. These are source
wiring classifications, not a claim that every provider's live data was verified today.

| Count | Visible component | Accepted baseline | After pass |
|---:|---|---|---|
| 4 | Kraken, Aqua/MatchTrader, IBKR, Robinhood Crypto surfaces | REAL_CONNECTED | REAL_CONNECTED |
| 4 | Provider letter/orbit emblems (intentional accepted art, not official logos) | REAL_CONNECTED | REAL_CONNECTED |
| 4 | Decorative provider headlines | PLACEHOLDER | PLACEHOLDER |
| 1 | Room title / instruction text | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Previous arrow | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Next arrow | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Selected-broker dots / ordinal | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Tap surface / horizontal swipe | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Slide back button | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Active-account count footer | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Load / error label | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Robinhood Crypto coverage notice | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Account selector / explicit multi-account choice | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Account name | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Connection label for manual accounts | WRONG_SOURCE | REAL_CONNECTED |
| 1 | Observation timestamp | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Freshness label (previously persisted flag only) | STALE_SOURCE | REAL_CONNECTED |
| 1 | Position collection / empty-state message | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Instrument / direction | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Quantity / entry | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Position P/L / stop | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Position observation timestamp | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Account currency | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Balance | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Equity | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Cash | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Buying power | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Account open P/L | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Retained evidence disclaimer | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Account records destination | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Robinhood connection / Confirm Trade destination | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Internal workspace destination (Secret/Admin only) | REAL_CONNECTED | REAL_CONNECTED |
| 1 | Execution authority disclaimer | REAL_CONNECTED | REAL_CONNECTED |

Baseline total: 42 definitions: REAL_CONNECTED 36, PLACEHOLDER 4,
STALE/WRONG_SOURCE 2. SAMPLE_DATA 0; DEAD_CONTROL 0; WRONG_ICON 0;
WRONG_ROLE 0; UNKNOWN 0. These counts exclude absent controls.
After pass, the same 42 definitions: REAL_CONNECTED 38, PLACEHOLDER 4.
Decorative headlines remain accepted presentation, not fabricated account facts.

### Newly visible additions (not included in baseline denominator)
- Workstation menu/globe: REAL_CONNECTED.
- Universal sheet: REAL_CONNECTED existing owner-scoped GET data.
- Universal account list including manual accounts: REAL_CONNECTED.
- Universal positions: REAL_CONNECTED, normalized account/provider labels.
- Universal total equity/exposure: UNAVAILABLE_BY_DESIGN; no unsafe sums.
- Discovery/safari: REAL_CONNECTED existing destination, paid/internal gate.
- Watchlist/star: REAL_CONNECTED existing state and symbol-detail navigation.
- Journal & performance/calendar: REAL_CONNECTED existing calendar destination.
- Refresh/arrow.clockwise: REAL_CONNECTED GET-only, coalesced and foreground-throttled.
- Account status: REAL_CONNECTED existing account status field.
- Manual capability/pencil.line: REAL_CONNECTED explicit source/connection mode.
- Current position price, TP, provider/account context: REAL_CONNECTED when supplied.
- Orders/fills/list.bullet.rectangle: UNAVAILABLE_BY_DESIGN in room; account endpoint
  supplies no authoritative collection. Never displayed as zero/empty.
- Capability/lock.shield: UNKNOWN for execution/management from this endpoint;
  manual accounts explicitly have no API execution or automated fills.

No visible dead controls were discovered. Universal/Discovery/Watchlist/Journal were
absent, not dead buttons; this pass adds real destinations instead of mock actions.
Replay, Research, Trading Lab, Auto Trader and diagnostics have no new Gold entry.
Their existing Secret/Admin navigation remains unchanged. Public Replay wiring and
shared orders/fills/capability DTOs remain REAL_BACKEND_NOT_WIRED where existing
appropriate sources exist; they are not invented in this pass.

## Truth and scope
- Kraken, Aqua, IBKR: existing normalized account/open-position GET paths; no new
  provider request, reconnect or credential flow. Currency and observation times shown.
- Aqua: only `isActive` records in operational room/Universal; history remains in the
  existing account-records destination. Server account status is also visible.
- Robinhood: Crypto only. No equity/options/whole-portfolio inference. Existing
  connection screen and frozen Confirm Trade flow unchanged.
- Manual: included in Universal even when provider is outside the four room families.
  Explicit manual balance timestamp, no live sync/API execution/automated fills.
- Position P/L marked unavailable by the normalized source is not displayed as known.
  Reported SL/TP prices are not claimed to prove active protection.
- Universal does not sum mixed currencies, stale/unavailable equity or incompatible
  exposure units. Row counts are retained-record counts, not total coverage claims.

## State / performance
Broker rotation/expansion variables are unchanged. Account selection survives refresh
if its identity still exists; multiple accounts never silently pick the first row.
Removed selections clear; a single account can auto-select. Account and position reads
fail independently and retain prior evidence with a failure warning. No polling loop;
foreground account reads are throttled to 30 seconds, explicit refresh coalesces while
in flight. No network request is triggered by animation. Access-token changes clear
owner-bound presentation rows; denied capability closes customer sheets and clears data.

## Role matrix
| Role | Room / Universal / Discovery / Watchlist / Calendar | Internal workspace / research / Auto Trader |
|---|---|---|
| Free | No new access; existing Free behavior unchanged | Denied |
| Gold | Customer room access, existing destination/server authorization applies | Denied |
| Secret | Customer room plus existing authorized internal route | Existing Secret authorization |
| Admin | Customer room plus existing authorized internal route | Existing Admin authorization |
| Banned / unresolved | Denied | Denied |

Client routing does not grant backend permission or execution authority.

## Validation
20 focused tests: BrokerRoomAccessTests, BrokerRoomEvidenceTests,
InternalWorkspaceAuthorizationTests, DashboardHeaderStructureTests.
Includes role combinations, ban/unresolved rejection, selection continuity, manual
source semantics, timestamp expiration, missing/future evidence and stale override.
Canonical build/install and iPad compilation results recorded in final report.
Physical visual review remains owner-owned; Mac mirroring requires iCloud sign-in.

## Next bounded candidates
1. Account-specific normalized orders/fills and shared capability contract in room.
2. Customer-safe accepted Replay route using genuine retained episode authorization.
3. Broker-specific connection/settings navigation without entering internal workspace.
4. Safe currency/coverage-aware aggregate values only when the contract supports them.

No broker orders, broker mutations, backend deployment, or execution/ML changes.

Final verification: device Debug build and generic iOS Simulator build PASS (device
families 1 and 2). Final 1.0 (14) installed in place on Otis iPhone 15 Pro without
uninstall/reset. Room/stage geometry and RoomBroker/environment definitions compared
byte-for-byte with accepted baseline: UNCHANGED. Physical iPhone/iPad visual acceptance
is not claimed from compiler or install success.
