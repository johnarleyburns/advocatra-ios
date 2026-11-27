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
- **Bundle ID** `guru.parso.advocatra` (reusing the existing `guru.parso`
  prefix) — unconfirmed assumption, cheap to change before any App Store
  Connect record exists.
- **Project generation:** XcodeGen `project.yml` will be added once the app
  target exists; not yet in this scaffold.

### Layout

```
Package.swift            AdvocatraCore (+ AdvocatraCoreTests)
AdvocatraCore/            pure-Swift mirror of packages/case + packages/billing
AdvocatraCoreTests/       Swift Testing suites proving the same invariants
                          as the TS unit tests (hand-ported, not shared code)
docs/architecture/TECHNICAL-DESIGN.md   mirrored copy
```

`AdvocatraSync` (the `/api/v1`-equivalent client) and the SwiftUI app target
are not yet created — see TECHNICAL-DESIGN.md's milestone order.

## Commands

| Command | Purpose |
| --- | --- |
| `swift test` | Swift Testing suites, works on Linux or macOS |

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

- One task, one small branch, one PR, squash merge. Never push to `main`.

## Hard limits for agents

1. **Never deploy, tag, or upload to TestFlight, and never touch secrets,
   environments or rulesets**, without an explicit, one-time owner request
   for that specific action.
2. Never add a GPL/AGPL dependency or copy GPL code.
3. Never commit keys, tokens, or any real taxpayer/client data.
4. Never guess a missing decision; stop and ask, or record it in
   `TECHNICAL-DESIGN.md` §9.
5. Never invent web/Android behaviour: schema changes come from the web repo.
6. Never run a simulator unless the owner asks.

## Definition of done (every PR)

- A test failed first and passes now; `swift test` is green with no warnings.
- No secrets, environments, rulesets, tags or TestFlight uploads touched.

## Status

Foundational scaffold: `AdvocatraCore` mirrors the web repo's case/billing
schema, with Swift Testing suites proving the key invariants. No storage,
sync, or UI yet.
