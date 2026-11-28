# Kraken onboarding draft repair

## Root cause

Commit `3d0c6d8` added destructive cleanup to BrokerManagementPanel's scene-phase callback: every non-active transition cleared the API key and secret. That includes switching apps to copy the second credential. The same change cleared both fields on disappearance and lane changes. View-local @State additionally could not survive reconstruction of the management view. Provider/account refresh did not require either destructive action.

## Repair

- One memory-only KrakenConnectionDraft owns the unfinished form independently of SwiftUI view/sheet identity. There is no Codable/UserDefaults/file/Keychain/analytics persistence for this draft.
- Ordinary backgrounding, foregrounding, lane switching and account refresh do not clear it. Auth token renewal does not clear it. New authentication session/logout use AuthSessionCoordinator's existing session-clear path to clear it.
- Name, classification, API key and API secret survive clipboard round trips. Name is editable and separate from classification and connection ID.
- Credentials clear after registration success, explicit Cancel and clear draft, logout/session replacement, or 15 minutes since the last edit. Expiration is checked on resume before uncovering the privacy shield. App termination loses the draft by design. Swift String clearing removes references; this is not a claim of guaranteed RAM zeroization.
- UIKit willResignActive installs an opaque scene window before the app-switcher snapshot. didBecomeActive expires stale drafts before removing the shield. SecureField protects both key and secret; no reveal control. Snapshot behavior still needs physical acceptance.
- Explicit labels, black-on-white inputs and gray prompts fix contrast. Name/key/secret validation disables registration. Errors retain the draft and show a bounded message rather than arbitrary response bodies that might echo submitted data.
- Requests retain the existing registration endpoint, owner authentication and credential fingerprint identity. No synchronization/reconnect, registration or broker mutation was invoked during this repair. The existing Business connection was not changed.

## Naming limitation (not silently hidden)

The existing backend request schema requires `ownership_type` to be `personal` or `business` (defaults to personal). This repair does not claim optional classification is implemented. The UI says the service currently requires a classification; it never sends an unspecified value and silently labels it Personal. A nullable classification needs a related backend contract/serialization change. Display name is fully editable now and is not overwritten by classification selection. Multiple names/classes are not used as credential identity: existing backend registration matches owner/provider/API-key fingerprint. Reusing an existing key can update that same connection; distinct Personal credentials are required for a distinct identity. No real registration was performed to prove a new identity.

## Validation

20 focused tests passed, zero failures: five new draft tests plus existing Kraken connection selection/sync and broker instrument/access tests. Covered repeated clipboard-length intervals, retaining key/secret/name/classification, classification/name independence, cancellation/success clear, timeout, stale completion isolation and required input validation.

Device Debug build passed. Canonical com.APLDEVO.ChaseINGreen 1.0 (14) updated in place and launched on Otis's iPhone 15 Pro (UDID ending 0109001C). No uninstall or data reset; Deon's phone untouched.

Physical keyboard-open backgrounding, refresh-in-flight, app-switcher snapshot masking, actual logout and successful separate Personal registration remain owner acceptance items. Unit tests are not a substitute for those physical results. No real credentials were captured or logged for testing. Existing transport logs request route/timing/error type, not the submitted request body; the new catch does not render raw decode errors.

Backend changes/deployments: none. Orders: 0. Broker mutations: 0. Existing Business connection: untouched. Unrelated local changes: preserved.
