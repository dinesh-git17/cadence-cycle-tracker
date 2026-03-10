# App Lock

**Epic ID:** PH-12-E2
**Phase:** 12 -- Settings
**Estimated Size:** M
**Status:** Draft

---

## Objective

Implement LocalAuthentication-based app lock for the Tracker role: an in-Settings toggle that enrolls the device's biometric/passcode authentication, enforcement logic that presents an opaque lock overlay when the app returns to the foreground after backgrounding, and persistence of the lock preference across launches. When this epic is complete, a Tracker who enables app lock cannot bypass it without authenticating via Face ID, Touch ID, or passcode.

## Problem / Context

Health data apps handling sensitive menstrual cycle information are an obvious target for snooping by a shared-device household member or someone who picks up an unlocked phone. The MVP Spec §11 explicitly includes "App lock (Face ID / passcode)" as a Tracker-side setting. PHASES.md Phase 12 in-scope specifies "LocalAuthentication: Face ID / Touch ID / passcode, lock on app background." Without app lock, the Tracker's data is accessible to anyone who has physical access to an unlocked device.

LocalAuthentication on iOS uses `LAContext.evaluatePolicy(.deviceOwnerAuthentication, ...)` to gate on biometrics with passcode fallback. The lock must engage on `scenePhase == .background` (not `.inactive`) to avoid triggering on transient events like control center pull-down. The overlay must cover all content before `LAContext.evaluatePolicy` is called to prevent information leakage during the authentication prompt.

`isAppLockEnabled` is a user preference (not a secret) and is stored in `UserDefaults` -- this is the standard iOS app-lock-enabled-state pattern. The lock overlay reads `isAppLockEnabled` at each foreground transition. Keychain is not needed for the preference flag itself; Keychain would be needed if a PIN were stored client-side, which is not the case here (the OS handles all credential storage via LocalAuthentication).

**Source references that define scope:**

- MVP Spec §11 (Privacy and Settings -- Tracker settings: App lock (Face ID / passcode))
- PHASES.md Phase 12 in-scope (app lock: LocalAuthentication: Face ID / Touch ID / passcode, lock on app background)
- cadence-accessibility skill (44pt touch targets on all interactive elements)
- swiftui-production skill (@Observable, no force unwraps beyond noted exceptions)

## Scope

### In Scope

- `AppLockView` in `Cadence/Views/Settings/AppLockView.swift`: `Form`-based settings screen navigable from `TrackerSettingsView` via `SettingsDestination.appLock`; contains a single `Toggle("App Lock", isOn: $isLockEnabled)` row with a `footnote` description below it: `"Require Face ID, Touch ID, or passcode when opening Cadence"`; a secondary `Text` displays the biometric type available on the device (`"Face ID"`, `"Touch ID"`, or `"Passcode"`) derived from `LAContext.biometryType` at view appearance; toggle tint is `Color("CadenceTerracotta")`
- `AppLockViewModel` in `Cadence/ViewModels/AppLockViewModel.swift`: `@Observable` class; reads `isAppLockEnabled` from `UserDefaults.standard` (key: `"cadence.appLock.enabled"`) on init; `toggleLock(enabled: Bool) async throws` handles enrollment (S2) and disablement; exposes `biometryTypeLabel: String` derived from `LAContext().biometryType`
- LocalAuthentication enrollment on toggle-on (S2): call `LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &error)` before any UI change; if the device has no passcode configured (error is `LAError.passcodeNotSet`), present an alert `"Set a Passcode"` with message `"Enable a device passcode in iOS Settings before using Cadence App Lock."` and revert the toggle to false; if biometrics/passcode are available, call `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enable Cadence App Lock")` -- on success, set `UserDefaults.standard["cadence.appLock.enabled"] = true`; on failure (user cancelled or biometric failure), revert toggle to false without showing an additional alert (LAContext presents its own failure UI)
- LocalAuthentication disablement: when the toggle moves from true to false, call `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Disable Cadence App Lock")` -- user must authenticate to turn off lock; on success, set `UserDefaults.standard["cadence.appLock.enabled"] = false`; on LAError.userCancel or LAError.authenticationFailed, revert toggle to true (cannot disable lock without authenticating)
- `AppLockOverlayModifier` in `Cadence/Views/Settings/AppLockOverlayModifier.swift`: a `ViewModifier` that overlays a full-screen `CadenceBackground`-colored view with a centered `lock.fill` SF Symbol icon (48pt, `CadenceTextSecondary`) and `"Cadence"` wordmark in `title2` + `CadenceTextPrimary`; applied to the Tracker shell root view (the `TabView` in Phase 4); overlay is visible when `AppLockState.isLocked == true`
- `AppLockState` in `Cadence/Services/AppLockState.swift`: `@Observable` singleton-pattern class instantiated at the app level (not a true singleton -- injected via environment); properties: `isLocked: Bool`, `isAuthenticating: Bool`; method `evaluateLock() async` that calls `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Cadence")`; on success, sets `isLocked = false`; on LAError.userCancel, keeps `isLocked = true` and sets `isAuthenticating = false` (do not re-prompt automatically; let the user tap to retry)
- Lock trigger: `@Environment(\.scenePhase)` observed at the `TrackerTabView` level; on transition from `.active` to `.background`, if `UserDefaults.standard.bool(forKey: "cadence.appLock.enabled") == true`, set `AppLockState.isLocked = true`; do NOT trigger on `.inactive` (transient state)
- On cold launch: in the root `App` struct's `body`, read `UserDefaults.standard.bool(forKey: "cadence.appLock.enabled")`; if true, initialize `AppLockState` with `isLocked = true` before `TrackerTabView` renders; the `AppLockOverlayModifier` covers content immediately
- Retry-on-tap: when the overlay is visible and `isAuthenticating == false`, tapping anywhere on the overlay calls `AppLockState.evaluateLock()`; this allows the user to retry after a cancellation; a `ProgressView` replaces the lock icon while `isAuthenticating == true`
- `project.yml` updated with entries for `AppLockView.swift`, `AppLockViewModel.swift`, `AppLockOverlayModifier.swift`, `AppLockState.swift`; `xcodegen generate` exits 0

### Out of Scope

- App lock for the Partner role (not specified in source documents; MVP Spec §11 Partner settings do not include app lock)
- PIN-based lock (LocalAuthentication delegates all credential management to iOS; no client-side PIN storage)
- Biometric enrollment (the device's biometric registration is managed by iOS Settings; Cadence only calls `evaluatePolicy`)
- Timed lock (lock after N minutes of inactivity) -- not specified in source documents; lock triggers only on background transition
- Jailbreak detection or anti-tampering (post-beta security hardening, out of MVP scope)
- App lock affecting the Partner shell -- Partner app lock is out of scope for this beta phase

## Dependencies

| Dependency                                                                     | Type     | Phase/Epic | Status   | Risk |
| ------------------------------------------------------------------------------ | -------- | ---------- | -------- | ---- |
| Phase 4 Tracker shell (`TrackerTabView`) to attach `AppLockOverlayModifier`    | FS       | PH-4       | Open     | Low  |
| `SettingsDestination.appLock` routing from `TrackerSettingsView` (PH-12-E1-S1) | FS       | PH-12-E1   | Open     | Low  |
| LocalAuthentication framework (system framework, no third-party dependency)    | External | Apple SDK  | Resolved | Low  |

## Assumptions

- `LAContext.biometryType` is read at `AppLockView` appearance time (not cached at app launch) to reflect the current device biometric configuration.
- `LAContext().evaluatePolicy(.deviceOwnerAuthentication, ...)` on a device with Face ID presents the Face ID prompt automatically. On a device with Touch ID, the Touch ID prompt appears. On a device with neither (or biometrics disabled by the user in iOS Settings), passcode entry is presented by iOS.
- The `AppLockOverlayModifier` is applied as `.modifier(AppLockOverlayModifier(state: appLockState))` on the `TrackerTabView` -- this placement ensures the overlay covers the entire Tracker UI including the tab bar.
- The lock state is not shared between the Tracker and Partner roles. If a device switches roles (unlikely in beta, but possible), the lock state is independently managed per role.
- `UserDefaults.standard` is acceptable for storing `isAppLockEnabled` because the preference flag is not a credential. The actual authentication is handled by iOS via `LAContext`.

## Risks

| Risk                                                                                                         | Likelihood | Impact                                            | Mitigation                                                                                                                                                                                            |
| ------------------------------------------------------------------------------------------------------------ | ---------- | ------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `LAContext.evaluatePolicy` is called on a background thread, causing a UI deadlock                           | Low        | High -- app becomes unresponsive                  | Always call `evaluatePolicy` on a `Task` with `@MainActor` -- `LAContext` is documented to call its reply block on an arbitrary thread; use `await MainActor.run` to update `AppLockState` properties |
| Device has no passcode set; user enables app lock -- `canEvaluatePolicy` fails silently                      | Low        | Medium -- lock is enabled but cannot authenticate | The `LAError.passcodeNotSet` check in `AppLockViewModel.toggleLock` catches this case and shows an alert before any state change                                                                      |
| Overlay covers `NotificationCenter` alerts or iOS system UI                                                  | Low        | Low -- system UI always renders above app content | `AppLockOverlayModifier` uses `.overlay` not `.fullScreenCover`; iOS system alerts render above overlay content regardless                                                                            |
| `scenePhase` transitions to `.inactive` during Face ID prompt (iOS triggers this for system-level UI events) | Medium     | Low -- false lock trigger                         | Lock triggers ONLY on `.background`, not `.inactive`, per the scope definition; `.inactive` is explicitly excluded                                                                                    |

---

## Stories

### S1: AppLockView + AppLockViewModel -- Settings Screen

**Story ID:** PH-12-E2-S1
**Points:** 2

Implement `AppLockView` and `AppLockViewModel`. The view shows a `Toggle` for enabling app lock, a description label, and the detected biometric type. Reads and writes `isAppLockEnabled` from `UserDefaults`. The toggle calls `AppLockViewModel.toggleLock(enabled:)` on change.

**Acceptance Criteria:**

- [ ] `AppLockView` is navigable from `TrackerSettingsView` via `SettingsDestination.appLock`
- [ ] The view contains a `Toggle("App Lock", isOn: binding)` with description `"Require Face ID, Touch ID, or passcode when opening Cadence"` in `footnote` + `CadenceTextSecondary` below the toggle row
- [ ] A secondary label below the description reads the biometric type: `"Device supports Face ID"`, `"Device supports Touch ID"`, or `"No biometrics available -- passcode only"` based on `LAContext().biometryType` evaluated at `onAppear`
- [ ] Toggle tint is `Color("CadenceTerracotta")`
- [ ] `AppLockViewModel` is `@Observable`; init reads `UserDefaults.standard.bool(forKey: "cadence.appLock.enabled")` and sets `isLockEnabled` accordingly
- [ ] `AppLockViewModel` exposes `biometryTypeLabel: String` computed from `LAContext().biometryType` (`.faceID` -> `"Face ID"`, `.touchID` -> `"Touch ID"`, `.opticID` -> `"Optic ID"`, `.none` -> `"Passcode"`)
- [ ] No hardcoded hex colors; toggle tint via token only
- [ ] `AppLockView.swift` and `AppLockViewModel.swift` added to `project.yml`

**Dependencies:** PH-12-E1-S1 (SettingsDestination.appLock routing)
**Notes:** `LAContext` must be instantiated locally in `biometryTypeLabel` -- do not store a reference to an `LAContext` instance on the view model (LAContext instances are single-use for evaluation; reuse for type query is fine but creates coupling).

---

### S2: LocalAuthentication Enrollment + Disablement Flow

**Story ID:** PH-12-E2-S2
**Points:** 3

Implement `AppLockViewModel.toggleLock(enabled: Bool) async throws`. Handles three paths: enabling lock (canEvaluatePolicy check -> evaluatePolicy confirmation -> UserDefaults write), disabling lock (evaluatePolicy re-authentication -> UserDefaults clear), and error cases (passcode not set alert, user cancellation toggle revert).

**Acceptance Criteria:**

- [ ] Toggling the `AppLockView` switch to `true` calls `toggleLock(enabled: true)` which first checks `LAContext().canEvaluatePolicy(.deviceOwnerAuthentication, error: &err)`; if the check fails with `LAError.passcodeNotSet`, an alert is presented with title `"Set a Passcode"`, message `"Enable a device passcode in iOS Settings before using Cadence App Lock."`, and a single `"OK"` button; the toggle reverts to false after the alert
- [ ] If `canEvaluatePolicy` succeeds, `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Enable Cadence App Lock")` is called; on success, `UserDefaults.standard.set(true, forKey: "cadence.appLock.enabled")` is written and `isLockEnabled` stays true
- [ ] If `evaluatePolicy` fails during enrollment (LAError.userCancel or authentication failure), `isLockEnabled` reverts to false; no additional alert is shown (LAContext presents its own failure UI)
- [ ] Toggling the switch from true to false calls `toggleLock(enabled: false)`, which calls `evaluatePolicy` with `localizedReason: "Disable Cadence App Lock"`; on success, `UserDefaults.standard.set(false, forKey: "cadence.appLock.enabled")` and `isLockEnabled` stays false
- [ ] If disablement `evaluatePolicy` fails, `isLockEnabled` reverts to true (user cannot turn off lock without authenticating)
- [ ] Unit test (mock LAContext): `toggleLock(enabled: true)` with mock returning success -> `UserDefaults["cadence.appLock.enabled"] == true`
- [ ] Unit test (mock LAContext): `toggleLock(enabled: true)` with mock returning `LAError.userCancel` -> `UserDefaults["cadence.appLock.enabled"] == false` and `isLockEnabled == false`
- [ ] Unit test (mock LAContext): `toggleLock(enabled: false)` with mock returning `LAError.authenticationFailed` -> `UserDefaults["cadence.appLock.enabled"]` unchanged as true and `isLockEnabled == true`

**Dependencies:** PH-12-E2-S1
**Notes:** `LAContext` does not conform to a protocol out of the box. For testability, define a `LocalAuthEvaluating` protocol with `canEvaluatePolicy` and `evaluatePolicy` methods, and make `LAContext` conform via extension. Inject a mock conformer in unit tests. This is the only approach that allows testing without a physical device.

`NSFaceIDUsageDescription` must be present in the `info.plist` section of `project.yml` before Face ID evaluation succeeds at runtime -- its absence causes a crash (`NSFaceIDUsageDescription not set in Info.plist`). Add this key to `project.yml` in this story:

```yaml
info:
  properties:
    NSFaceIDUsageDescription: "Cadence uses Face ID to protect your health data."
```

Run `xcodegen generate` and verify the key appears in the built `.app` bundle's Info.plist before testing on device. Touch ID and passcode flows do not require this key, but its absence blocks Face ID on any device that attempts it.

---

### S3: Lock Overlay Modifier + ScenePhase Trigger

**Story ID:** PH-12-E2-S3
**Points:** 5

Implement `AppLockState`, `AppLockOverlayModifier`, and the `scenePhase` observation that locks the app on background transition. Apply the overlay to `TrackerTabView`. Implement retry-on-tap for cancelled authentications.

**Acceptance Criteria:**

- [ ] `AppLockState` is `@Observable` with `isLocked: Bool` and `isAuthenticating: Bool` properties; `evaluateLock() async` sets `isAuthenticating = true`, calls `LAContext().evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock Cadence")`, sets `isLocked = false` on success, or sets `isLocked = true` and `isAuthenticating = false` on failure
- [ ] `AppLockOverlayModifier` renders a full-screen `ZStack` overlay when `state.isLocked == true`: background is `Color("CadenceBackground")`, centered content is a `lock.fill` SF Symbol at 48pt `CadenceTextSecondary` when `isAuthenticating == false`, or a `ProgressView` when `isAuthenticating == true`, with `"Cadence"` text in `title2` + `CadenceTextPrimary` below the icon
- [ ] Tapping anywhere on the overlay when `isAuthenticating == false` calls `AppLockState.evaluateLock()`; the tap gesture uses `.onTapGesture` on the overlay's root view
- [ ] `AppLockOverlayModifier` is applied to `TrackerTabView` via `.modifier(AppLockOverlayModifier(state: appLockState))` where `appLockState` is injected at the app level and passed via environment
- [ ] `@Environment(\.scenePhase)` observed at `TrackerTabView`; on transition to `.background`, if `UserDefaults.standard.bool(forKey: "cadence.appLock.enabled") == true`, set `appLockState.isLocked = true`; does NOT trigger on `.inactive`
- [ ] `evaluateLock()` and all `AppLockState` property mutations run on `@MainActor` (verified: no runtime main-thread checker violations)
- [ ] UI test: with `AppLockState(isLocked: true)` injected via environment, `AppLockOverlayModifier` renders and the `lock.fill` icon is visible
- [ ] UI test: with `AppLockState(isLocked: false)`, the overlay is absent and the underlying `TrackerTabView` is visible
- [ ] `AppLockOverlayModifier.swift` and `AppLockState.swift` added to `project.yml`

**Dependencies:** PH-12-E2-S2, PH-4 (TrackerTabView)
**Notes:** `AppLockState.isLocked` is initially `false` at app launch unless the cold launch path in S4 sets it to `true`. The `scenePhase` observer is the ongoing lock trigger post-launch. Do not use `UIApplication.shared.applicationState` -- the `scenePhase` environment value is the SwiftUI-idiomatic approach.

---

### S4: Cold Launch Lock + UserDefaults Persistence

**Story ID:** PH-12-E2-S4
**Points:** 2

Implement cold-launch lock enforcement: when the app launches with `isAppLockEnabled == true`, `AppLockState.isLocked` is set to `true` before `TrackerTabView` renders. Verify persistence survives app termination and relaunch.

**Acceptance Criteria:**

- [ ] In the root `App` struct's `body`, before `TrackerTabView` is instantiated, `UserDefaults.standard.bool(forKey: "cadence.appLock.enabled")` is read; if `true`, `AppLockState(isLocked: true)` is passed to the environment
- [ ] On cold launch with app lock enabled, the overlay is the first visible content the Tracker sees -- `TrackerTabView` content (home feed, tab bar) is not visible before authentication
- [ ] Killing the app and relaunching (cold launch) correctly triggers the lock overlay if app lock is enabled
- [ ] Backgrounding the app and returning (warm resume via scenePhase) correctly triggers the lock overlay if app lock is enabled (covered by S3, verified end-to-end here)
- [ ] Disabling app lock (S2) and then cold-launching: overlay does not appear
- [ ] `UserDefaults.standard.bool(forKey: "cadence.appLock.enabled")` is the single source of truth for lock state at launch; no secondary `@AppStorage` property duplicates this read
- [ ] Physical device test: enable app lock, terminate the app via iOS app switcher, relaunch -- overlay appears immediately before any app content

**Dependencies:** PH-12-E2-S3
**Notes:** The root `App` struct reads `UserDefaults` synchronously at startup. This is an acceptable startup cost (sub-millisecond dictionary lookup). Do not use async initialization patterns for this preference read.

---

## Story Point Reference

| Points | Meaning                                                                              |
| ------ | ------------------------------------------------------------------------------------ |
| 1      | Trivial. Config change, single-file edit, well-understood pattern. < 1 hour.         |
| 2      | Small. One component or function, minimal unknowns. Half a day.                      |
| 3      | Medium. Multiple files, some integration. One day.                                   |
| 5      | Significant. Cross-cutting concern, multiple components, testing required. 2-3 days. |
| 8      | Large. Substantial subsystem, significant testing, possible unknowns. 3-5 days.      |
| 13     | Very large. Should rarely appear. If it does, consider splitting the story. A week.  |

## Definition of Done

- [ ] All stories in this epic are complete and merged
- [ ] All acceptance criteria pass
- [ ] No P0/P1 bugs open against this epic's scope
- [ ] Physical device end-to-end verified: enable app lock -> background app -> return to foreground -> Face ID / Touch ID / passcode prompt appears -> authenticate -> Tracker Home is visible
- [ ] Physical device end-to-end verified: kill app -> relaunch -> overlay appears before any Tracker content
- [ ] Physical device end-to-end verified: disable app lock -> background -> return -> no overlay
- [ ] Phase objective is advanced: Tracker can enable and use app lock from the Settings tab
- [ ] Applicable skill constraints satisfied: swiftui-production (@Observable for AppLockState and AppLockViewModel, no force unwraps except the documented LAContext localReason constant, no AnyView), cadence-design-system (no hardcoded hex, CadenceBackground overlay, CadenceTerracotta toggle tint), cadence-accessibility (44pt touch target on overlay tap area, VoiceOver label on lock icon)
- [ ] `scripts/protocol-zero.sh` exits 0
- [ ] `scripts/check-em-dashes.sh` exits 0
- [ ] Build compiles without warnings under SWIFT_TREAT_WARNINGS_AS_ERRORS
- [ ] Accessibility: lock overlay `lock.fill` icon has `accessibilityLabel("App is locked. Tap to authenticate.")` and `accessibilityAddTraits(.isButton)`
- [ ] `NSFaceIDUsageDescription` key present in `project.yml` info.plist properties and verified in built bundle before device testing
- [ ] Offline-first: app lock enforcement requires no network call (fully local -- LAContext + UserDefaults)
- [ ] No dead code, stubs, or placeholder comments
- [ ] Source document alignment verified: LocalAuthentication usage matches MVP Spec §11 and PHASES.md Phase 12 app lock in-scope exactly

## Source References

- PHASES.md: Phase 12 -- Settings (in-scope: app lock, LocalAuthentication: Face ID / Touch ID / passcode, lock on app background)
- MVP Spec §11 (Privacy and Settings -- Tracker settings: App lock (Face ID / passcode))
- Design Spec v1.1 §3 (Color system -- CadenceBackground for overlay, CadenceTerracotta for toggle tint)
- Design Spec v1.1 §14 (Accessibility -- 44pt touch targets, VoiceOver labels)
- swiftui-production skill (@Observable, no AnyView, no force unwraps)
- cadence-accessibility skill (touch target enforcement, VoiceOver label patterns)
