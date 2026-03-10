# TestFlight Build Distribution

**Epic ID:** PH-14-E6
**Phase:** 14 -- Pre-TestFlight Hardening
**Estimated Size:** M
**Status:** Draft

---

## Objective

Configure code signing via Fastlane match, register the app record in App Store Connect, provision the internal TestFlight group, and ship the first signed IPA to the beta cohort (Carolina, Dinesh's sister, and close friends with their partners). This epic is the final gate of Phase 14 and the MVP beta. It cannot begin until the CI gate chain is passing (Epic 1), coverage thresholds are met (Epic 2), UI tests are green (Epic 3), and Dinesh has signed off on device validation (Epic 5).

## Problem / Context

All prior Phase 14 epics verify that the app is correct, tested, and complete. This epic delivers the build to real users. Three distinct systems must be configured before the first upload can succeed: (1) App Store Connect -- app record, bundle ID, TestFlight internal group; (2) Fastlane match -- code signing certificates and provisioning profiles stored in a private repository; (3) CI pipeline -- the `testflight` job has the six required secrets and produces a signed IPA that passes Apple's binary upload validation. Each system has a concrete configuration gate that will cause the CI `beta` lane to fail if misconfigured. Working through them sequentially eliminates the most common root causes of first-build failures.

## Scope

### In Scope

- App Store Connect app record creation: bundle ID `com.cadence.tracker`, app name, primary language, primary category
- Apple Developer account: verify `com.cadence.tracker` App ID is registered with Push Notifications and Sign in with Apple capabilities enabled
- Match certificates repository: a new private GitHub repository (`cadence-certs` or similar) initialized with `fastlane match init`
- `match(type: "appstore")` run with `readonly: false` locally (once only) to generate the Distribution certificate and App Store provisioning profile; these are encrypted and stored in the match repo
- All six required secrets provisioned in GitHub repository Settings > Actions secrets per cadence-ci skill §7
- First successful `bundle exec fastlane beta` run locally: signs IPA, uploads to TestFlight, build appears in App Store Connect processing queue
- Internal TestFlight group "Cadence Internal" created in App Store Connect; beta cohort members added (Carolina, Dinesh's sister, invited friends and partners)
- Build number confirmed correctly incrementing from `latest_testflight_build_number + 1` on each subsequent CI push

### Out of Scope

- App Store submission and review (post-beta per MVP Spec Out of Scope for Beta)
- External TestFlight group distribution (internal group only during beta)
- Privacy policy or nutrition labels (pre-App Store requirement, not pre-TestFlight)
- Anonymous or guest mode (out of scope for beta per MVP Spec §11)
- App Store Connect metadata (screenshots, description, keywords) -- not required for internal TestFlight
- Crashlytics or Firebase SDK integration (no third-party analytics in beta build per MVP Spec Privacy NFR)

## Dependencies

| Dependency                                                                  | Type     | Phase/Epic        | Status | Risk   |
| --------------------------------------------------------------------------- | -------- | ----------------- | ------ | ------ |
| CI pipeline (lint, build, unit-tests, ui-tests gates all passing on main)   | FS       | PH-14-E1          | Open   | High   |
| Unit test coverage gate passing (xcov 80%+ threshold met)                   | FS       | PH-14-E2          | Open   | High   |
| UI test suite passing in CI                                                 | FS       | PH-14-E3          | Open   | High   |
| Device validation signed off by Dinesh                                      | FS       | PH-14-E5          | Open   | High   |
| Apple Developer Program membership active for the team account              | External | Apple / Dinesh    | Open   | High   |
| App Store Connect API key created (key ID + issuer ID + .p8 file available) | External | App Store Connect | Open   | Medium |
| Private match certificates repository created on GitHub                     | External | Dinesh            | Open   | Low    |

## Assumptions

- Dinesh or the team account has an active Apple Developer Program membership (individual or organization, $99/year). TestFlight upload requires a paid developer account.
- `com.cadence.tracker` bundle ID is not already registered to a conflicting app -- if it is, a different bundle ID must be chosen and `project.yml`, `fastlane/Appfile`, and `ci.yml` must all be updated consistently.
- The App Store Connect API key used for CI is of type "App Manager" or higher -- lesser roles cannot upload builds to TestFlight.
- The match certificates repository will be a new private GitHub repository, initialized locally with `fastlane match init`. It is not the same repository as the app source code.
- "Internal Testers" in App Store Connect refers to users who are part of the Apple Developer team (App Store Connect users). The beta cohort (Carolina, friends) who are not team members must be added as External Testers to a TestFlight external group -- adjust the `upload_to_testflight(groups:)` parameter accordingly if the cohort are not App Store Connect team members.

## Risks

| Risk                                                                                                                                  | Likelihood | Impact | Mitigation                                                                                                                                                                                                                                                                                                                                                                  |
| ------------------------------------------------------------------------------------------------------------------------------------- | ---------- | ------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `com.cadence.tracker` bundle ID is already registered under a different Apple Developer account                                       | Low        | High   | Check the Apple Developer portal before beginning S1. If taken, choose `com.dinesh.cadence.tracker` or equivalent and update all three reference points (project.yml, Appfile, provisioning profile).                                                                                                                                                                       |
| App Store Connect API key has insufficient role to upload TestFlight builds                                                           | Medium     | High   | Create the key with "App Manager" role minimum. "Developer" role cannot upload binaries. Verify role in App Store Connect > Users and Access > Integrations > App Store Connect API.                                                                                                                                                                                        |
| First match run generates a certificate that immediately conflicts with an existing Distribution certificate on the developer account | Low        | Medium | If the account already has a Distribution certificate, match will reuse it (not create a duplicate). If the certificate is expired or invalid, run `fastlane match nuke distribution` to revoke and regenerate. Coordinate with any other app on the same developer account before nuking.                                                                                  |
| Beta cohort members are not Apple Developer team members and cannot be added to the Internal Testers group                            | High       | Medium | Add cohort as External Testers. Create a TestFlight external group "Cadence Beta" and add their Apple IDs or emails. Update the `upload_to_testflight` Fastfile call: `groups: ["Cadence Beta"]`, `distribute_external: true`. Note: external groups require at minimum a Beta App Review (Apple review of the build for TestFlight distribution) -- this may add 1-2 days. |
| CI `testflight` job fails on first run due to a missing or incorrectly encoded secret                                                 | Medium     | High   | Before the first CI push to `main`, verify all six secrets are set by running `bundle exec fastlane beta` locally with the secrets set as environment variables. Confirm locally before relying on CI.                                                                                                                                                                      |

---

## Stories

### S1: App Store Connect App Record and Bundle ID

**Story ID:** PH-14-E6-S1
**Points:** 2

Register the `com.cadence.tracker` App ID in the Apple Developer portal with the required capabilities, and create the Cadence app record in App Store Connect.

**Acceptance Criteria:**

- [ ] `com.cadence.tracker` App ID is registered in Apple Developer > Certificates, Identifiers & Profiles > Identifiers with the following capabilities enabled: Push Notifications, Sign in with Apple
- [ ] A Cadence app record exists in App Store Connect under the developer team -- visible in My Apps
- [ ] App name is set (e.g., "Cadence") and primary language is set to English (or Dinesh's preference)
- [ ] Bundle ID in the app record matches `project.yml` `PRODUCT_BUNDLE_IDENTIFIER` exactly (`com.cadence.tracker`)
- [ ] The app record's primary category is set (Health & Fitness or similar -- Dinesh's decision)
- [ ] No App Store Connect metadata (screenshots, privacy policy, description) is required at this stage -- TestFlight internal distribution does not require it

**Dependencies:** None within this epic
**Notes:** If `com.cadence.tracker` is already taken under a different account, choose an alternative (e.g., `com.dinesh.cadence`, `com.cadence.ios.tracker`) and update `project.yml` PRODUCT_BUNDLE_IDENTIFIER, `fastlane/Appfile` app_identifier, `ci.yml` testflight job env references, and all provisioning profiles before continuing. Document the final bundle ID here so subsequent stories use the correct value.

---

### S2: Match Certificates and Provisioning Profiles

**Story ID:** PH-14-E6-S2
**Points:** 5

Initialize the Fastlane match certificates repository, generate the App Store Distribution certificate and App Store provisioning profile for `com.cadence.tracker`, encrypt and store them in the match repo, and verify they can be fetched from CI.

**Acceptance Criteria:**

- [ ] A private GitHub repository (e.g., `cadence-certs`) is created under Dinesh's GitHub account or the team org
- [ ] `fastlane match init` is run locally with the HTTPS URL of the private match repo -- `fastlane/Matchfile` is generated with `git_url`, `app_identifier`, `username`
- [ ] `fastlane match appstore` is run locally with `readonly: false` (once only, not in CI) -- this generates the Distribution certificate and App Store provisioning profile, encrypts them with `MATCH_PASSWORD`, and pushes to the match repo
- [ ] The match repo contains at minimum: an encrypted `.cer` file, an encrypted `.mobileprovision` file, and a `README.md` generated by match
- [ ] `fastlane match appstore --readonly true` can be run locally (simulating CI) and successfully fetches the certificate and profile into the local Keychain without error
- [ ] `MATCH_GIT_URL`, `MATCH_GIT_TOKEN`, and `MATCH_PASSWORD` secrets are set in GitHub repository Settings > Actions secrets
- [ ] `match(readonly: true)` in the `beta` lane succeeds in a local dry-run with the environment variables set

**Dependencies:** PH-14-E6-S1
**Notes:** `fastlane match init` uses the `git_url` as the HTTPS URL of the private match repo. Use `git_basic_authorization` or `MATCH_GIT_TOKEN` (PAT with repo read access) for CI auth -- SSH keys require additional CI setup. The MATCH_PASSWORD must be consistent across all `match` operations -- losing it requires revoking all certificates and starting over. Store it in a password manager, not only in GitHub secrets.

---

### S3: First Local Beta Lane Run

**Story ID:** PH-14-E6-S3
**Points:** 3

Run `bundle exec fastlane beta` locally with all environment variables set to verify the complete lane executes end-to-end: `setup_ci`, `app_store_connect_api_key`, `match(readonly: true)`, `increment_build_number`, `build_app`, and `upload_to_testflight`. The first successful upload proves the lane is correctly configured before relying on CI.

**Acceptance Criteria:**

- [ ] `bundle exec fastlane beta` completes locally with exit code 0 -- no lane step fails
- [ ] Build number is correctly set to `latest_testflight_build_number + 1` -- confirmed by Fastlane output showing the previous build number and the new value
- [ ] `build_app` produces a `.ipa` file in `./fastlane/` or Xcode's derived data output directory -- file exists and is non-empty
- [ ] `upload_to_testflight` output confirms the build was submitted to Apple's processing queue (`skip_waiting_for_build_processing: true` is set, so the lane does not block waiting for processing)
- [ ] The build appears in App Store Connect > TestFlight > Builds within 30 minutes of upload, in "Processing" or "Ready to Submit" state
- [ ] No Fastlane deprecation warnings related to `readonly: false` appear -- the local run used `match(type: "appstore", readonly: true)` (not `readonly: false`)
- [ ] `.env.secret` is not committed -- confirmed by `git status` showing no changes to `.env.secret`

**Dependencies:** PH-14-E6-S2
**Notes:** Run `bundle exec fastlane beta` with `APPLE_ID`, `APPLE_TEAM_ID`, `APP_STORE_CONNECT_API_KEY_ID`, `APP_STORE_CONNECT_API_ISSUER_ID`, `APP_STORE_CONNECT_API_KEY_CONTENT`, `MATCH_PASSWORD`, `MATCH_GIT_URL`, and `MATCH_GIT_TOKEN` all set as shell environment variables. Use a `.env.secret` file loaded via `dotenv` or `export` statements -- never committed. If the lane fails at `match`, debug the match repo URL, token, and password. If it fails at `build_app`, check the provisioning profile name against the Xcode project's signing settings.

---

### S4: Internal TestFlight Group and Beta Cohort

**Story ID:** PH-14-E6-S4
**Points:** 3

Create the TestFlight distribution group for the beta cohort, add the cohort members, and confirm the first processed build is available for installation. Verify at least one cohort member successfully installs and launches the build.

**Acceptance Criteria:**

- [ ] A TestFlight group exists in App Store Connect named "Cadence Internal" (if cohort are App Store Connect team members) or "Cadence Beta" (if cohort are external testers)
- [ ] All intended beta cohort members are added to the group by Apple ID or email address
- [ ] If the cohort are external testers: Beta App Review is submitted (App Store Connect > TestFlight > External Groups > [group] > Add Build); review typically completes in < 24 hours for TestFlight
- [ ] Once the first build finishes processing, cohort members receive a TestFlight invitation email or the build appears in their TestFlight app under the Cadence entry
- [ ] At least one cohort member (Carolina or Dinesh's sister) confirms successful app installation via TestFlight on their iPhone
- [ ] The installed build launches, completes the splash animation, and reaches the Auth screen -- confirming the Release build runs on a non-developer device
- [ ] Build number `1` (or the initial number from `latest_testflight_build_number + 1`) is confirmed in the TestFlight app on the cohort member's device

**Dependencies:** PH-14-E6-S3
**Notes:** Beta App Review is required for external TestFlight groups but not for internal (team member) groups. If the beta cohort are not Apple Developer team members, allow 1-2 days for review. The review checks for basic crash-free launch and compliance with App Store guidelines -- it does not review the full app experience. There is no way to programmatically add external testers via Fastlane's `upload_to_testflight` action -- external group assignment in App Store Connect is done manually once.

---

### S5: CI-Triggered TestFlight Verification

**Story ID:** PH-14-E6-S5
**Points:** 2

Squash merge a PR to `main` after all five gate jobs are passing and confirm the CI `testflight` job runs, produces a higher build number than the local S3 build, and uploads successfully to TestFlight.

**Acceptance Criteria:**

- [ ] A PR with a non-trivial code change (e.g., a config comment update) is squash-merged to `main` with all five CI gates green
- [ ] The `testflight` CI job triggers as a result of the push to `main` -- the `if: github.ref == 'refs/heads/main' && github.event_name == 'push'` condition evaluates to true
- [ ] The `testflight` job completes with exit code 0; the GitHub Actions run shows all five jobs green
- [ ] The build number in the new CI upload is exactly 1 greater than the build uploaded in S3 -- confirmed by checking the TestFlight build list in App Store Connect
- [ ] No secrets appear in the CI job logs -- confirmed by reviewing the `testflight` job log output; secret values are masked as `***` in GitHub Actions
- [ ] The new CI build is visible in the TestFlight distribution group within 30 minutes of CI completion

**Dependencies:** PH-14-E6-S3, PH-14-E6-S4, PH-14-E1-S6 (full CI gate chain verified green)
**Notes:** The PR used for this verification should have a non-trivial code change so the build number is genuinely incremented and the IPA is a fresh binary. A pure whitespace-only diff may be rejected by `build_app` if Xcode detects no changes (rare but possible with some build system caching). If the `testflight` job fails due to a certificate expiry or match issue, re-run `match(readonly: false)` locally to renew and re-push to the match repo, then re-trigger CI.

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
- [ ] CI pipeline (lint -> build -> unit-tests -> ui-tests -> testflight) passes end-to-end on push to `main`
- [ ] `match(readonly: true)` in CI never fails -- certificate and provisioning profile are valid and accessible
- [ ] Build number increments correctly on each CI push to `main`
- [ ] Beta cohort (Carolina, Dinesh's sister, invited friends and partners) have received TestFlight invitations and at least one member has successfully installed the build
- [ ] The installed build launches, completes the splash animation, and reaches the Auth screen on a non-developer device
- [ ] No secret values are exposed in CI logs
- [ ] Phase 14 primary goal achieved: the first TestFlight build has been distributed to the known beta cohort
- [ ] PHASES.md Completion Standard satisfied: Buildable and passing CI; deployable via TestFlight to the known beta cohort; functionally complete per Phase 14 completion standard
- [ ] Applicable skill constraints satisfied: cadence-ci §§6-10 (TestFlight gate, match readonly, setup_ci, secret scoping, app_identifier), cadence-git (Conventional Commits on all commits reaching main)
- [ ] `scripts/protocol-zero.sh` exits 0 on any files modified by this epic
- [ ] `scripts/check-em-dashes.sh` exits 0 on any modified files

## Source References

- PHASES.md: Phase 14 -- Pre-TestFlight Hardening (likely epic: TestFlight build distribution)
- PHASES.md Completion Standard (Deployable via TestFlight to the known beta cohort; Buildable and passing CI)
- cadence-ci skill §6 (TestFlight gate -- setup_ci, match readonly, increment_build_number, upload_to_testflight groups Internal Testers)
- cadence-ci skill §7 (Required secrets -- all six must be provisioned before testflight job runs)
- cadence-ci skill §8 (Fastlane configuration files -- Gemfile, Appfile, Fastfile beta lane)
- cadence-ci skill §10 (Anti-pattern table -- match readonly: false in CI is Reject)
- Design Doc §1 (MVP targets a private beta via TestFlight -- App Store submission is post-beta)
- MVP Spec Target Users > Beta Cohort (Carolina, Dinesh's sister, close friends and their partners; TestFlight distribution; no public App Store release)
- MVP Spec Out of Scope for Beta (App Store submission and compliance)
- MVP Spec Privacy NFR (No third-party analytics SDKs in the beta build)
