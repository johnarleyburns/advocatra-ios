<!-- SPDX-License-Identifier: AGPL-3.0-only -->
# CLAUDE.md — Advocatra for iPhone (`johnarleyburns/advocatra-ios`)

This repo is the iPhone track of Advocatra, an open-source IRS
representation case management tool. The web/cloud track is
`johnarleyburns/advocatra`; the Android track is
`johnarleyburns/advocatra-android`. All three mirror
`docs/architecture/TECHNICAL-DESIGN.md`.

## Source of truth

1. `docs/architecture/TECHNICAL-DESIGN.md` — the architecture baseline.
   Schema changes land in the web repo first and get hand-mirrored here in
   the same logical change; never invent a field or invariant here.
2. This file.
3. The GitHub issue being worked.

## Stack and identity

- **Swift 6 language mode**, strict concurrency. `AdvocatraCore` must also
  build on Linux (this repo's test job runs there), so it never imports
  SwiftUI, StoreKit, Keychain or networking — only portable Swift/Foundation
  types. No Foundation DOM-XML classes (`XMLDocument`/`XMLElement`); if the
  vault format ever needs XML, hand-roll it the way Saldima's
  `cross-platform-api-verification` lesson requires.
- **Bundle ID** `guru.parso.advocatra` — confirmed: matches the real App ID
  and App Store Connect record the owner created (Team ID `3264Y8YUGV`).
- **Project generation:** XcodeGen `project.yml` → `Advocatra.xcodeproj`.
  Never hand-edit the generated project; run `xcodegen generate` after
  changing `project.yml`. The generated project is gitignored, regenerated
  fresh by every CI run and by anyone building locally.

### Layout

```
project.yml               XcodeGen project definition
Package.swift             AdvocatraCore (+ Tests) and, Apple-only
                          (`#if canImport(Darwin)`), AdvocatraVault (+ Tests)
AdvocatraCore/             pure-Swift mirror of packages/case + packages/billing
AdvocatraCoreTests/        Swift Testing suites proving the same invariants
                          as the TS unit tests (hand-ported, not shared code)
AdvocatraVault/             real createVault/unlockVaultWith*, the cloud
                          client (login, GET/PUT /vault/manifest, GET
                          /vault/snapshot), and Keychain storage of the
                          unwrapped master key — CryptoKit/Security, so
                          Apple-only; see TECHNICAL-DESIGN.md §5
AdvocatraVaultTests/        round-trip tests plus hardcoded cross-platform
                          vectors (from advocatra's
                          scripts/generate-vault-fixtures.mjs) proving
                          byte-identical output against the real web
                          implementation — see CrossPlatformFixtureTests.swift
Advocatra/App/             @main App struct, minimal DI
Advocatra/Features/Vault/  sign in -> create-or-unlock vault -> connected;
                          read-only (no upload/lease yet). Real
                          case-management UI beyond this is separate,
                          not-yet-started work
Advocatra/Resources/Info.plist
Support/allowed-dependencies.txt   remote Swift package allow-list (empty so far)
scripts/                   CI guard scripts (see Commands)
.githooks/pre-commit        installed via `git config core.hooksPath .githooks`
docs/architecture/TECHNICAL-DESIGN.md   mirrored copy
```

`AdvocatraVault/Networking/AdvocatraCloudClient.swift` covers login and the
vault manifest/snapshot routes. Uploading a snapshot (lease acquisition,
`POST /vault/snapshot`) is still not implemented — see TECHNICAL-DESIGN.md's
milestone order.

## Commands

| Command | Purpose |
| --- | --- |
| `xcodegen generate` | regenerate `Advocatra.xcodeproj` from `project.yml` |
| `swift test` | Swift Testing logic suites (macOS or Linux container) |
| `scripts/test.sh` | wrapper used locally and in CI |
| `bash scripts/check-swift6.sh` | reject Swift 5 modes and concurrency escape hatches |
| `bash scripts/check-observable.sh` | reject `ObservableObject` |
| `bash scripts/check-seams.sh` | reject bare `Date()`/`UUID()` in `AdvocatraCore` |
| `bash scripts/check-spdx.sh` | every authored file carries the AGPL SPDX header |
| `bash scripts/check-licenses.sh` | remote Swift packages must be allowlisted with a permissive licence |
| `bash scripts/check-workflows.sh` | actionlint over `.github/workflows/` |

Do not start or boot a simulator unless the owner explicitly asks. CI
compiles for generic iOS and runs logic tests on a macOS runner; the Linux
container job covers portable logic.

## Test-first, always

- Write the failing test first, watch it fail for the right reason, then
  the smallest change that passes.
- Every invariant (Tax Court requiring `taxCourtDetails`, the fee-schedule
  guarantee window, required-field rules by pricing type) needs a `@Test`
  that proves it, matching the TS package's test for the same rule.
- No sleeping or wall-clock reads in tests; pass `now` explicitly.

## Money and data invariants

- Money amounts are `Int` cents, never `Double`/`Float`/`Decimal`.
- SSN/EIN and other PII fields must never appear in a log or error message
  in the clear.
- `minimumGuaranteeDays` is 30; `FeeSchedule.init` refuses less without an
  explicit `overrideReason`.

## License and dependencies

- **AGPL-3.0-only**, sole copyright retained by `johnarleyburns` through
  `CLA.md`; outside PRs require the CLA check.
- SPDX header on every authored file.
- Dependencies must be MIT, BSD, Apache-2.0, ISC, 0BSD or CC0.
- Advocatra is an independent implementation; its architecture is
  consciously modeled on Saldima's public design (same author) — see
  `NOTICE`.

## Git and GitHub workflow

- **One task, one small branch, one PR, squash merge. Never push to `main`.**
  Use the `gh` CLI for every GitHub action.
- Install hooks with `git config core.hooksPath .githooks`; pre-commit runs
  `swift test`.

## TestFlight (automatic, owner-merge-gated)

- `.github/workflows/testflight.yml` fires on every push to `main` (i.e.
  every merged PR). A gate job checks whether the merge came from a pull
  request authored by `johnarleyburns`; direct pushes and PRs from anyone
  else are skipped, logged via `::notice`, not silently ignored.
- Before archiving, a "Preflight secrets" step checks all eight required
  secrets and skips the archive/upload steps (reporting exactly which
  secret is missing) rather than failing opaquely if any aren't set yet.
- Required secrets: `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`,
  `APP_STORE_CONNECT_API_KEY_P8_BASE64`, `BUILD_CERTIFICATE_BASE64`,
  `BUILD_PROVISION_PROFILE_BASE64`, `DEVELOPMENT_TEAM_ID`,
  `KEYCHAIN_PASSWORD`, `P12_PASSWORD`.

## Hard limits for agents

1. **Never deploy, tag, or upload to TestFlight by hand, and never touch
   secrets, environments or rulesets unless the owner explicitly asks.**
   Open PRs only. TestFlight uploads are automatic as described above —
   that automation is the one exception, and it only fires through a
   merged, owner-authored PR, never a direct agent action.
2. Never create or modify the `ios-release` environment, App Store Connect
   keys, certificates, provisioning profiles, branch protection or Actions
   secrets without an explicit owner request. (The current secrets were
   set once, this way, from files the owner handed over — see Status.)
3. Never add a GPL/AGPL dependency or copy GPL code.
4. Never commit keys, tokens, certificates, provisioning profiles, or any
   real taxpayer/client data.
5. Never guess a missing decision; stop and ask, or record it in
   `TECHNICAL-DESIGN.md` §9.
6. Never invent web/Android behaviour: schema changes come from the web repo.
7. Never run a simulator unless the owner asks.

## Definition of done (every PR)

- A test failed first and passes now; compile, tests and guards are green
  with no warnings.
- No secrets, environments, rulesets, tags or manual TestFlight uploads
  touched.

## Status

`AdvocatraCore` mirrors the web repo's case/billing schema, with Swift
Testing suites proving the key invariants. CI/CD is set up: `ci.yml`
(Linux portable-logic job, Apple unsigned-compile job, actionlint job) and
`testflight.yml` (owner-merge-gated, secrets-preflight-gated).

The real vault now exists on iOS: `AdvocatraVault` (Apple-only, gated by
`#if canImport(Darwin)` in `Package.swift` so Linux's `swift test` simply
doesn't see it) has `createVault`/`unlockVaultWithPassphrase`/
`unlockVaultWithRecoveryCode`, independently implemented against
CryptoKit — verified byte-identical to the real web implementation where
cross-platform interop matters (not just internally consistent), via
hardcoded vectors from `advocatra`'s `scripts/generate-vault-fixtures.mjs`
in `AdvocatraVaultTests/CrossPlatformFixtureTests.swift`. The wrap step is
AES-256-GCM, not AES-KW — CryptoKit has no AES-KW primitive, so both
platforms switched (see `advocatra`'s `TECHNICAL-DESIGN.md` §5).
`AdvocatraCloudClient` logs in and talks to `GET`/`PUT /vault/manifest`
and `GET /vault/snapshot`; the unwrapped master key is stored in the
Keychain gated by biometrics/passcode (`VaultKeychain`, untestable in CI —
needs manual verification on a real device). The app target
(`Advocatra/Features/Vault/`) drives sign-in → create-or-unlock → a
"connected" screen showing decrypted record counts — read-only, no
upload/lease yet.

All eight TestFlight secrets are now set, per an explicit owner request for
each piece added this round:
`DEVELOPMENT_TEAM_ID`/`BUILD_PROVISION_PROFILE_BASE64`/`APP_STORE_CONNECT_KEY_ID`/
`APP_STORE_CONNECT_API_KEY_P8_BASE64`/`KEYCHAIN_PASSWORD` (from files the
owner provided, read once, never committed) plus `APP_STORE_CONNECT_ISSUER_ID`
(given directly by the owner) and `BUILD_CERTIFICATE_BASE64`/`P12_PASSWORD`
(a brand-new Apple Distribution certificate, generated end to end on this
machine — RSA key + CSR via `openssl`, signed by Apple through the App
Store Connect API using the existing API key, packaged into a `.p12` —
since the owner explicitly asked for that specific action).

The original `BUILD_PROVISION_PROFILE_BASE64` (from the owner's
`.mobileprovision`) embedded only a pre-existing certificate whose private
key was never available here, so it couldn't sign with the new
certificate. With the owner's explicit go-ahead, the stale profile was
deleted and replaced via the same API with one bound to the new
certificate (verified: embedded certificate serial matches the new
cert's). This is the one exception to hard limit #2's default — every
certificate/profile action here was a specific, explicit owner request,
not an agent judgment call.

Not yet done: uploading a snapshot from iOS (lease acquisition, `POST
/vault/snapshot`), real case-management UI beyond the "connected" summary
screen, and attachment/document content. `VaultKeychain`'s actual
Keychain read/write needs manual verification on a real device — a
headless CI runner has no way to satisfy a `.userPresence` biometric
prompt, so it isn't exercised by `AdvocatraVaultTests`.
