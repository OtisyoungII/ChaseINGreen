# Entitlement incident — November 24, 2026

## Proven facts and limits

Production revision: 7231e407511b024d859b5b200bdc7ada71a42331. Read-only owner lookup used the established retained ETH episode owner identity, not email as entitlement proof. The owner row has plan/admin override admin; Admin, Secret, Gold and Premium flags true; banned false. No verified Apple subscription environment, original reference, expiration or verification timestamp is retained for this owner. That does not establish whether the Apple account owns an unlinked purchase.

Authenticated production traffic at 17:03 UTC (12:03 PM ET) shows /me 200 alongside repeated /me/apple-subscription/context 503. This log evidence does not itself disclose the response body or prove which signed-in identity was on the recorded screen. The canonical handler returns that 503 when purchase_configuration_ready cannot construct Apple's verification components. Render's existing service environment UI shows no APPLE_* variables, no secret files, and no linked environment group. No secrets were revealed or copied.

## Four truths

- Apple purchase: UNKNOWN; no verified backend record for the owner, and production verification setup is unavailable. StoreKit product availability/prices are not purchase evidence.
- Backend commercial entitlement: no verified Apple paid entitlement retained. /me plan=admin is effective access, not a commercial billing record; the current /me contract does not separately serialize commercial origin.
- Internal authority: Admin and Secret remain true via the established admin override/authorization path.
- Effective product access: Gold-equivalent access remains enabled for the owner. Gold intelligence, Pre-Trade, broker-aware capabilities and internal position-sizing gates admit this authority. Journal and Calendar remain available independently. Gold alone cannot grant Admin/Secret. Actual device endpoint exercise remains subject to physical acceptance.

## Root causes

1. SubscriptionPaywallView initialized serverPlan=free, serverVerified=false and rendered false from showsGold as Free. It loaded StoreKit/products/sync before fetching /me. Every loading period therefore appeared Free, and missing token/profile errors explicitly reset to Free.
2. The same view converted internal Admin access into a Gold subscription label and ignored Secret in its expanded-access presentation. It always offered Subscribe regardless of verified access or verification availability.
3. Apple server verification is unavailable in production. This is a real purchase/restore verification outage, not proof that Otis lost Admin access or had a paid entitlement revoked.

The exact transient state/frame in the owner's recording cannot be uniquely reconstructed from aggregate request logs. The initial/error Free display is deterministic in the inspected source and reproduced by the replacement policy regression tests. Do not claim all customers lost paid access.

## Lifecycle

StoreKit verified currentEntitlements / Transaction.updates -> account-bound appAccountToken obtained from authenticated context -> signed JWS sync -> Apple signed-data and current subscription-status verification -> app_users verified subscription fields -> request-specific effective_access -> CurrentUser -> /me -> CurrentUserResponse -> SessionCapabilityProfile / InternalWorkspaceAuthorization -> feature gates. SubscriptionPaywallView separately revalidates /me and formerly manufactured its own Free fallback.

Products: chaseingreen_gold_monthly / chaseingreen_gold_yearly; backend also recognizes existing legacy aliases. No product or price was changed. Transaction ownership, expiration/revocation, bundle, production/sandbox and signature checks remain unchanged. Restore still invokes AppStore.sync and then the existing authenticated sync. No restore or purchase was performed by the agent.

Backend deliberately uses request-specific Apple verification rather than a positive authorization cache. Verification-unavailable can deny paid access under that existing fail-closed policy. This audit does not weaken it or fabricate entitlement. Existing inactive/expired/revoked rules remain unchanged. Admin override is independent of paid status. Current /me does not expose uncertainty/billing-origin detail; a future backend repair should add explicit commercial/verification metadata without changing privileges.

## Owner correction / scope

The confirmed incident is that Gold cannot currently be purchased. There is no allegation of a customer being charged without activation. No historical charge investigation is part of this repair. Product display does not prove successful purchasing.

## Bounded client repair

- SubscriptionAccountPresentation uses Checking/Unavailable/Last verified states; malformed or contradictory public plan data cannot become verified Free.
- Current internal authority is explicitly described as internal access, not a paid Apple subscription. Gold product access and Apple evidence are separate.
- Fetch /me before StoreKit work. A per-view loading guard avoids repeating initial work on task reentry.
- Preserve last verified presentation during uncertainty, explicitly marked stale; authoritative Free still replaces old Gold.
- Disable purchasing unless server profile is current Free, account is unrestricted/noninternal, no local verified Gold exists, and authenticated purchase context is ready.
- Local StoreKit uncertainty is explicit; failed sync no longer empties previously verified local evidence solely because the network/configuration is unavailable. Local evidence never grants server access.

No API/model authorization logic, backend code, environment, customer row, product, price, broker or execution setting changed.

## Server repair boundary

Restore the existing service's Apple verification configuration through its normal secure configuration workflow: APPLE_BUNDLE_ID, APPLE_APP_ID, APPLE_ROOT_CERTIFICATES, APPLE_PRIVATE_KEY_PATH, APPLE_KEY_ID, APPLE_ISSUER_ID, with valid trust-root files and App Store Server API key file. Validate presence/readability and construction without printing contents. Do not create or replace keys or change production settings without the required owner-controlled trust material. Do not turn missing configuration into success or trust unsigned client metadata. No deployment performed.

## Validation and acceptance

41 Swift entitlement/internal-authorization tests passed, including 10 new presentation tests. 61 backend security/Apple route/review-profile tests passed against the exact deployed application modules (read-only baseline import harness), with no provider requests or production writes. Build/install and physical acceptance are recorded separately after completion. Tests are not owner acceptance.

## Device delivery

Canonical Debug build succeeded; signature verification passed. Verified bundle com.APLDEVO.ChaseINGreen, version 1.0, build 14. Installed in place on Otis iPhone 15 Pro, device 00008130-000158A20109001C; launch succeeded. No uninstall/reset occurred. No action targeted Deon's device. iPhone Mirroring reports iCloud Signed Out, so owner must open the Trade Home crown and provide physical judgment. Session/container continuity and displayed account result remain pending owner observation; install success alone is not acceptance.

Git: existing feature/ibkr-machine-neutral-enrollment checkout, HEAD 0ce2dabb4381667ce646ce1c3829314e4f941921; this task's three Swift source edits, new presentation test file and this report are isolated for a local P0 commit. No push/deployment. Unrelated pre-existing changes preserved.

Orders placed: 0. Broker mutations: 0. Subscription purchases: 0. Customer entitlements manually altered: 0.

## Configuration restoration progress

The existing active In-App Purchase key and its local private-key file have been located without printing their values. App Store Connect confirms both canonical products Approved in the same Gold subscription group. No replacement key is needed. Secure upload to the existing Render service is currently blocked by the ChatGPT browser extension file-URL permission. No Render configuration has been changed yet. Production purchase verification remains unqualified until the configuration is restored and authenticated context succeeds.

## Follow-up — record only

After reliable purchasing is proven, improve contextual Gold promotion using only verified, shipped capabilities. No upsell implementation belongs in this P0.
