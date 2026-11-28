# Batcave release candidate — 2026-11-28

## Scope and feature map

This is an integrated candidate, not a claim of production or physical acceptance.

| Capability | Existing destination / candidate change | State |
|---|---|---|
| Trade Home, searchable symbol, discovery, watchlist | Existing Dashboard routes retained | Preserved; physical acceptance pending |
| Accounts, broker onboarding, universal positions | Accounts · Batcave → existing spatial Broker Room → provider management | Consolidated; normalized truth preserved |
| Charts / technical analysis | Existing MarketDetailView, selected symbol/provider/account carried from broker surface | Gold local chart controls restored; EMA 12/26/50/200 and completed-candle ATR added |
| Support/resistance, RSI, MACD, Bollinger, VWAP | Existing chart components | Retained; volume-dependent evidence unavailable when volume is absent |
| Research / learning | Existing chart explanations and authorized research routes | Integrated; advanced/internal analysis remains restricted |
| Position sizing / planning | Existing chart → account-scoped sizing preview | Implemented; canonical account and fresh positive equity required; not executable |
| Scenarios | Existing chart evidence plus educational definitions | Partial: no invented predictive paths or confidence |
| Journal / calendar / performance | Trader OS menu → existing record-trade sheet / account-scoped Calendar | Integrated; closed-trade performance distinct from cash flows |
| AI assistance | Existing authorized analysis components | Preserved; no new model or privilege expansion |
| Admin / Auto Trader | Existing role-gated destinations | Intentionally restricted; no new execution authority |

Free keeps its legacy quick-entry and account routes. Gold chart tools do not grant internal quant, scanner, research diagnostics, Trading Lab, or Auto Trader access. Existing backend authorization remains authoritative.

## Data loading

The shared AppRefreshCoordinator coalesces account GETs by owner and historical scope. A bounded device-only Keychain cache provides retained account responses across launches (two slots, 512 KB maximum each, seven-day retention). Owner mismatch is rejected. Logout and ledger invalidation clear it. Provider timestamps are never renewed by caching. Failed reads retain prior evidence; this is not a claim of fresh provider synchronization.

The active Broker Room reads retained backend evidence every 30 seconds while visible. It neither contacts providers directly nor changes observer cadence, credentials, leases, or execution. Other existing refresh policies remain in force.

## Provider truth

Kraken, Robinhood Crypto, Aqua and IBKR retain their existing implemented paths and exact account identities. Robinhood Crypto is not equities/options/futures access. Coinbase, Crypto.com, Webull, Fidelity and Trade The Pool are not newly implemented integrations in this candidate; unsupported/manual capabilities must remain explicitly labeled. No new Aqua accounts or credentials were created. No IBKR Gateway or worker was operated.

## Verification

Exact selectively staged source export: 373 Swift tests passed, zero failures. Canonical Debug, optimized Release and device-signed Release builds succeeded. Bundle com.APLDEVO.ChaseINGreen, version 1.0 (14). The build excludes unrelated dirty replay/intelligence work. Privacy manifest includes the app's UserDefaults required-reason declaration.

Backend integration onto verified live 349d2c687283254f4205f3b4e1822c03de6e332d: 203 focused broker/auth/recovery regressions and 63 additional subscription/watchlist/sizing/calendar/access regressions passed. Five local PostgreSQL migration tests passed. See backend release plan for database/version limits.

Automated coverage addresses roles, owner isolation, cache deduplication and logout, stale evidence, chart warmup/missing volume, alias persistence, calendar scope and position-size permission. It does NOT constitute physical end-to-end acceptance, a live subscription purchase, broker onboarding with new credentials, or Keychain persistence acceptance on the phone.

## Release boundary / remaining acceptance

Production display_name migration and deployment are NOT performed. The current live schema lacks the column. Obtain explicit approval for the backend release sequence before installing the dependent candidate for complete acceptance.

Physical journeys A–G remain required: Gold chart → sizing → journal → calendar; existing/new provider account navigation; retained launch snapshot; historical/manual/personal/business distinctions; Free/Gold/Secret/Admin isolation; network/logout/restart; legacy chart parity. Use Otis's iPhone 15 Pro, in-place update only. Never claim physical acceptance from build/test results.

App Store submission is NOT performed or authorized. Build 14 is an existing development candidate, not a verified unused App Store upload number. Before upload, verify the next available build number, current App Store metadata/screenshots, privacy declarations including SDK manifests, account deletion and Restore, review credentials, subscription product display prices and legal/support URLs. Do not silently alter pricing or production authentication.

Apple references: https://developer.apple.com/app-store/review/guidelines/ ; https://developer.apple.com/help/app-review/before-submitting-for-review/complete-review/ ; https://developer.apple.com/documentation/technotes/tn3183-adding-required-reason-api-entries-to-your-privacy-manifest

No orders, broker mutations, provider credential changes, App Store uploads or production deployment occurred. Unrelated local work remains outside this commit.
