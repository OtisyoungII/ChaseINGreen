# Canonical native product recovery — 2026-11-17

Baseline: e8b5df1a4c6f62a17d87bf69be0b885c5604f786, branch feature/ibkr-machine-neutral-enrollment.

## Provenance and disposition

November 15 stash ccb5b0c14e91c9abca5087e284940b11fd9b71cc preserved newer uncommitted product state before the enrollment checkout. Seven exact saved files are selectively recovered; no stash was applied wholesale or deleted. See NATIVE_PRODUCT_RECOVERY_INVENTORY.json for every relevant saved path and generated-directory counts.

- RECOVER: Composer package (two files), both flat branding images, MarketDetailView, project safeguard, synthetic adaptive-layout harness.
- ALREADY PRESENT: Admin Operations/Cockpit models, service, views and tests are byte-identical to the November 15 untracked snapshot. The earlier audit overstated their omission. AdminHome already links to these screens via Broker Observation; the cockpit is embedded in that view.
- SUPERSEDED: AdminHome keeps current truthful activity, broker observation and Aqua intake links, rather than restoring the old label or maintenance section. Package.swift already includes Admin models and retains Aqua intake, IBKR and all current test targets. No replacement is necessary.
- OBSOLETE/TEMPORARY: old AquaRepairMaintenance model/tests, APIService repair and latch additions, AdminHome repair controls are excluded. Info.plist formatting/removal of explicit bundle metadata is not required for product recovery; current canonical identity/configuration is retained.
- GENERATED: .build and .swiftpm workspace artifacts are excluded from the commit.

November 4 stashes cc39553 and 562c306: 40 tracked files match the November 15 baseline exactly. The remaining seven are superseded: TradePresentationPolicyTests uses the newer currentBrokerEconomicsAvailable helper; TradePresentationPolicy adds that helper; BrokerLoginModels adds typed deletion evidence; OpenPositionsPanel adds unavailable/stale-price messaging; Dashboard uses equivalent key-path filtering plus today's account fixes; TradingWorkspace adds ledger invalidation plus today's exact-account selection; Info.plist retains current canonical configuration. Nineteen untracked source/test files are already identical to HEAD; the only missing legitimate harness is recovered. No unresolved older product change remains in those snapshots. Existing feature branches add no commits beyond main.

## Branding and feature preservation

Composer source and icon.json match the owner's preserved sculpted master byte-for-byte. Source SHA256: 9483f3371913434e92a870eb83ba9a3ec4cd0900aa1d788c8976347e695aa7fb. Configuration SHA256: bc7a1da6e45de9af53c58122f98a709706da4cdd14df1c6cdd84f7ad2e48c036. No redesign or setting changes.

Xcode's synchronized canonical target compiles AppIcon.icon and Assets.xcassets with --app-icon AppIcon. The built Assets.car contains AppIcon image stacks/groups, AppIcon_Assets/02-sculpted, and ChaseINGreenIcon. The packaged AppIcon60x60@2x.png was decoded using Apple's pngcrush into a temporary inspection image and visually verified as bull/bear. The old bank icon is no longer the selected source.

Discovery view/models, Watchlist and TradingCalendar match saved November 4 implementation at the later baseline. No November 15 Discovery delta exists. Current NVDA mappings/aliases remain. Current Calendar integration remains. Market Detail now displays every returned pattern and an explicit empty-evidence message, exactly as saved. This is source/build parity, not new live market-data qualification.

All files changed by post-baseline Gate 4/IBKR commits remain byte-identical to recovery-start HEAD. Aqua intake, account identity, manual removal, exact workspace selection and authorization remain intact. No backend, account data, observer, provider or execution settings changed. Cash removal is reserved for owner UI acceptance.

## Validation

- Full Swift package: 314 tests passed, zero failures, including Aqua intake, Admin Operations/Cockpit, authorization, IBKR identity, manual removal, Discovery/session truth, market presentation and Calendar tests.
- Canonical iOS Debug build: passed, normal target/scheme, no maintenance flags or identity overrides.
- Deep/strict code signature verification: passed.
- Built identity: com.APLDEVO.ChaseINGreen; display ChaseINGreen; build 14.
- Built debug dylib UUID: 4DAC450C-887E-3104-A0D0-3A95BA0842A5.
- Binary markers verified: AdminAutoTraderView, AdminTraderCockpit, AquaAPIIntakeView, OpportunityScreenerView, TradingCalendarView, MarketDetailView, Remove Manual Account, NVDA.
- Market Detail recovery is byte-identical to saved source and compiled; no new physical UI or live provider acceptance is claimed.
- git diff --check passed.

Physical acceptance remains separate: bull/bear Home Screen icon first, then current launch UI, Discovery, Admin Operations/Cockpit, Trade Home/Personal IBKR, manual Cash removal control and Aqua intake. No Aqua key entry or validation is part of recovery.
