# Native broker-room vertical slice

Source artifacts, read in full:
- `/Users/otisyoung/Downloads/brokers-room.html`
- `/Users/otisyoung/Downloads/batcave-workspace.html`
- `/Users/otisyoung/Downloads/batcave-replay.html`

The first artifact controls the room: shared provider palette, arch/floor environment,
three visible surfaces, rotation, and expansion of the selected persistent surface.
The workspace contributes explicit account selection and positions before account metrics.
Replay remains its existing implementation; no fixture candles or internal replay access
were imported into the customer room. The supplied sample account values are not used.

## Scope
Trade Home's concrete workspace-link component now opens the native BrokerRoomView.
Gold, Secret and Admin may enter the customer room using server-resolved capabilities.
Free behavior remains unchanged. Internal workspace authority is still Secret/Admin only;
the existing internal policy and destination gates are unchanged. Broker availability
never grants authority. Banned/unknown sessions cannot enter. Account session changes
clear retained presentation data.

Four existing providers rotate through three visible positions: Kraken, Aqua/MatchTrader,
IBKR and Robinhood Crypto. The selected surface expands and scrolls in place. Back leaves
the same provider selected. Reduced Motion disables transition animation.

Only existing authenticated GET account and open-trade paths load room evidence.
Multiple accounts require explicit selection. Missing facts are unavailable; retained
account freshness is shown. Robinhood Crypto explicitly excludes equities/options and
whole-portfolio claims. Existing Robinhood connection/Confirm Trade UI is linked unchanged.
No execution path, backend, provider configuration, credentials, or prototype data changed.

## Verification
- Canonical Debug device build: PASS, bundle com.APLDEVO.ChaseINGreen, 1.0 (14).
- Installed in place and launched on Otis iPhone 15 Pro, device ending 0109001C.
- Focused authorization and Dashboard concrete-boundary tests: 17 passed.
- Physical room interaction: PENDING OWNER ACCEPTANCE. Mac iPhone Mirroring reports
  iCloud Signed Out, so installation/launch do not prove visual acceptance.
- Real normalized data consumer: implemented; account content needs physical review.
- Confirm Trade source unchanged.

No broker orders or mutations performed. No backend deployment.
