<!-- SPDX-License-Identifier: AGPL-3.0-only -->
# Advocatra — Technical Design and Implementation Blueprint

This document is the architecture baseline for Advocatra. It is mirrored
verbatim into `advocatra-ios` and `advocatra-android` (same convention
Saldima uses for its three repos): whichever copy changes first, copy the
change to the other two in the same pull request.

## 1. Executive summary

Advocatra is an open-source, GnuCash-style-compatible-in-spirit (but *not*
GnuCash-compatible — it is a tax-representation case management tool, not an
accounting app) practice tool for solo EAs, CPAs and tax attorneys handling
IRS representation matters, including Tax Court.

| Offering | Price |
| --- | --- |
| Local web/PWA, native iOS, native Android | Free |
| Self-managed storage and backups | Free |
| Hosted encrypted cloud sync | $20/month or $200/year |

Explicit exclusions: tax preparation, automated legal advice, expert
recommendations, multi-user collaboration, and any server-side access to
taxpayer documents in the clear.

## 2. Architecture and module boundaries

Advocatra is **three independent implementations of one canonical format**,
not one shared codebase — deliberately, following Saldima's own precedent
and its own documented reason for it: an early Saldima iOS port built its
XML engine on Foundation's DOM-style `XMLDocument`/`XMLElement`, passed every
test on Linux (where `swift-corelibs-foundation` implements that API), and
then failed to compile on real iOS, which has no DOM XML API at all. The fix
was a hand-rolled, dependency-free Swift type using only `String`/`Array`/
`Dictionary`. The lesson generalizes: a standard-library API that looks
universal on one platform's Foundation/stdlib is not evidence it exists on
every deployment target. Advocatra applies this up front rather than
discovering it the hard way:

- `advocatra` (web/cloud, TypeScript) implements the canonical format
  natively in TS.
- `advocatra-ios` (`AdvocatraCore`, pure Swift) implements it again, by hand,
  using only portable Swift standard-library types.
- `advocatra-android` (`core`, pure Kotlin/JVM, no `android.*` imports)
  implements it a third time, by hand.

No package is shared across the three. Consistency is enforced by a written
schema and (from M3) a cross-platform fixture-verification repo
(`advocatra-case-verifier`), not by sharing code.

### Boundary rules (per repo, enforced by each repo's own `CLAUDE.md`)

- The case/billing domain packages are pure: no network, no platform
  framework (Cloudflare bindings, SwiftUI/StoreKit, `android.*`), no
  filesystem, no clock reads other than through an injected port.
- Only the storage adapter layer touches the actual vault (IndexedDB,
  on-device file/keystore, Durable Object + R2).
- Views/screens never hold business logic; they call into the domain
  package and render plain objects.

### The non-negotiable security boundary

**No plaintext taxpayer data, case document or vault encryption key ever
reaches the cloud API, Durable Object or R2 storage, in any form, from any
platform.** Encryption and decryption happen only in the browser (Web Crypto
API) or on-device (key protected by Keychain/Keystore). This is a stricter
bar than Saldima's *current* production implementation, where the Workers
runtime holds a `MASTER_KEY` secret and performs encryption server-side —
that is explicitly Saldima's Phase 1-3 state, with true zero-knowledge
described as a deferred Phase 4+ target in Saldima's own design doc.
Advocatra builds the stricter version from day one, because case files carry
SSNs, financial records and privileged work product, and because the
product's own marketing claim ("the server stores ciphertext, not readable
taxpayer records") must be true from the first release, not from some later
phase.

## 3. Canonical case format

There is no existing open standard for IRS representation case files
(unlike GnuCash XML for accounting). Advocatra therefore defines its own
versioned, documented schema — the same move Saldima made by picking
GnuCash XML as *its* canonical format, just without an existing standard to
anchor to. The schema lives in `packages/case` (web) and is mirrored by hand
in `AdvocatraCore` (iOS) and `core` (Android).

A **vault** contains:

```
manifest.json          format version, app version, schema version,
                        encryption algorithm id, vault id, document index,
                        last synced revision
taxpayers/              Taxpayer records
matters/                Matter records (see taxonomy below)
documents/               encrypted document/attachment objects, referenced
                        by id from a matter or correspondence record
correspondence/         Correspondence records
tasks/                  Task/deadline records
activity/               ActivityLogEntry records (append-only)
billing/
  fee-schedules/        FeeSchedule records (see section 6)
  engagements/          Engagement records
  time-entries/         TimeEntry records
  retainers/            Retainer records
  invoices/             Invoice records
  payments/             Payment records
```

This is a conceptual layout, realized on-disk on iOS/Android (iOS:
Application Support; Android: app-private storage) and, for the web client,
realized only as the decrypted-in-memory shape of whatever snapshot the
cloud API just returned — the browser has no local-first copy of this
layout at all (see §5).

### Core objects (representative fields, not exhaustive)

- **Taxpayer**: id, name, type (`individual`\|`business`), address, contact
  info, representation authorization on file (e.g. Form 2848, with date).
  SSN/EIN is stored as part of the encrypted record, never in cleartext
  anywhere the manifest or index can see it.
- **Matter**: id, taxpayerId, category (taxonomy below), matterType
  (free-text subtype), status (`open`\|`pending`\|`closed`), taxYears[],
  openedDate, closedDate, assignedPractitioner, notes, and — only when
  `category === "tax-court"` — a `TaxCourtDetails` block (section 4).
- **Document**: id, matterId, taxpayerId, type (notice, correspondence,
  pleading, discovery, order, financial, other), taxYear, description, and
  a reference to its encrypted object (never the plaintext bytes in the
  index).
- **Correspondence**: id, matterId, direction (`inbound`\|`outbound`), date,
  method (mail, fax, efax, portal, phone, email), summary, related document
  ids.
- **Task**: id, matterId, title, dueDate, status, assignedTo, reminderDate.
- **ActivityLogEntry**: id, matterId, timestamp, actor, type, description —
  append-only audit trail.

## 4. Matter taxonomy

Classifications, not mutually exclusive procedural paths — the practitioner
can customize matter type within a category.

| Category | Matter types |
| --- | --- |
| Examination | Correspondence audit, office audit, field audit |
| Collection | Installment agreement, OIC, CNC, levy, lien, enforcement |
| CDP | CDP hearing, equivalent hearing |
| Appeals | Examination Appeals, Collection Appeals Program |
| Penalties | Abatement, reasonable cause |
| Innocent spouse | IRC §6015 claims |
| Employment tax | Payroll tax disputes, trust fund recovery |
| Information reporting | Penalty and reporting disputes |
| Tax Court | Deficiency, collection, declaratory, other petitions |
| Other | General IRS representation |

**Tax Court is first-class**, not a future add-on. A Tax Court matter's
`TaxCourtDetails` block carries: court, docket number, petition date, notice
of deficiency date, petition deadline, answer date, assigned IRS counsel,
discovery status, motions[], trial session, settlement status, decision or
stipulated decision, appeal information. The practitioner maintains these
fields manually; there is no DAWSON integration in scope.

## 5. Local persistence and encryption

### Storage model per platform

This corrects an earlier draft of this document, which carried over a
browser-has-its-own-local-vault model from an initial sketch. That is not
the agreed design: **the web client has no local-first vault at all.** It
is a full-featured but cloud-dependent client — same features as the native
apps, no offline mode, nothing durable in IndexedDB/localStorage beyond
per-viewer conveniences. iOS and Android are the local-first platforms.

| Operation | Browser | iOS/Android |
| --- | --- | --- |
| Vault lives | only in the cloud (encrypted) | on-device, authoritative; optionally also synced to the cloud |
| Open vault | passphrase unlock → fetch encrypted snapshot from the cloud API → decrypt in-memory | passphrase/biometric unlock → decrypt the on-device vault directly |
| Add document | upload; encrypted client-side before the request leaves the browser | filesystem/photo picker; encrypted before being written to disk |
| Export vault | download the decrypted-then-re-encrypted-for-export archive for this session only | save a portable archive from the on-device vault, any time, no network |
| Import vault | n/a (there is nothing local to import into) | open archive, decrypt, replace or merge the on-device vault |
| Working offline | not supported — no cloud, no client | fully supported; this is the normal mode |
| Cloud sync | the client's only mode of operation | optional; snapshot upload/download per §7 |

A browser session with no network and no account is not a degraded version
of the product — it is simply the product you can't currently use there.
This is why the cloud subscription is "optional" for the native apps but
effectively required to do anything useful on the web.

### Encryption, every platform

Account authentication (email/password, Stripe subscription) is **always
separate** from vault encryption. The account password never becomes, or
derives, the encryption key.

Key hierarchy, implemented in `packages/crypto`/`packages/vault`, ported
from Saldima's own shipped zero-knowledge design (`packages/crypto`'s
`recovery.ts`/`vault-key.ts`/`passphrase-kdf.ts` and
`apps/web/src/client/vault.ts` there — not invented fresh):

- A random **vault master key** (`generateVaultMasterKeyMaterial`).
- Separate derived keys for the record index and for document objects
  (HKDF from the master key, distinct `info` strings per purpose —
  `deriveDataKey`).
- Per-object random nonces; AES-256-GCM everywhere, and every envelope's
  ciphertext is bound to `{ vaultId, purpose, schemaVersion }` as
  authenticated additional data (`EnvelopeAad`), so a valid envelope for
  one vault or purpose can't be replayed as another's.
- The vault master key is wrapped **two independent ways**, stored
  together in the manifest's `keyEnvelope` (`packages/vault/src/manifest.ts`):
  a passphrase-derived KEK (PBKDF2-SHA256, 600,000 iterations — Argon2id
  remains preferred if/when an audited WASM implementation is adopted, see
  §9) and a recovery-code-derived KEK (HKDF directly over a 20-byte random
  code, Crockford base32, grouped for transcription — no PBKDF2 needed,
  the code is already high-entropy machine output, not a human passphrase).
  Either secret alone unlocks the vault; losing both makes it permanently
  unrecoverable, by construction — the whole point of zero-knowledge. The
  wrap step itself is **AES-256-GCM** (a random 12-byte IV, output stored
  as `iv || ciphertext+tag`) rather than Web Crypto's AES-KW: the manifest
  is shared across every client of one tenant (web, iOS, Android, MCP),
  and Apple's CryptoKit has no AES-KW primitive, so AES-GCM is the one
  AEAD every platform's crypto library exposes — and it's a more literal
  reading of "AES-256-GCM everywhere" than AES-KW ever was.
  `createVault`/`unlockVaultWithPassphrase`/`unlockVaultWithRecoveryCode`
  in `packages/vault/src/vault-access.ts` are the only entry points; no
  client should hand-roll this sequence itself.
- Versioned encryption metadata on every object, so the format can evolve
  without breaking old vaults.

This applies uniformly: encrypted-at-rest on iOS/Android (protected by a
Keychain/Keystore-held key, unlocked by device passcode/biometric or an
app passphrase) — a deliberate departure from Saldima, whose iOS/Android
local `.gnucash` file is unencrypted by Saldima's own explicit design
decision. Advocatra cannot make that same call given the sensitivity of the
data it stores. The iOS/Android ports of `createVault`/`unlockVault*` are
not yet written — see §9.

## 6. Billing, engagements and fee schedules

A tax practice needs to know what it promised, what it's owed, and what's
been paid — this is as core to the product as the case file itself, and it
lives in the same encrypted vault (billing records for a named client are
themselves confidential).

### Objects

- **FeeSchedule** — the firm's published rate card, versioned.
  `effectiveDate`, `publishedAt`, `guaranteeDays` (default 30 — see the
  invariant below), line items: `{ id, serviceCode, label, pricingType:
  "flat"|"hourly", amount }` (e.g. `1040-W2` flat $80, `1040-SCHC-INVEST`
  flat $500, `HOURLY-STANDARD` hourly rate). `id` is what
  `Engagement.quotedFromLineItemId` (below) actually points at — without
  it there's nothing for that traceability link to reference, a gap an
  audit of this repo caught (the schema had no `id` field until then).
- **Engagement** — the actual commitment made to one client: taxpayerId,
  optional matterId, taxYear, description, pricingType
  (`flat`\|`hourly`\|`retainer`), committedAmount or hourlyRate, and a
  traceable link to which fee-schedule line item it was quoted from (or an
  explicit custom-quote override with a recorded reason). Status:
  `proposed`→`accepted`→`active`→`completed`\|`cancelled`.
- **TimeEntry** — for hourly engagements: date, `durationHours` as an
  arbitrary decimal (fractional-hour billing, no forced rounding), billable
  flag, description, and the hourly rate *snapshotted at entry time* so a
  later rate change never silently reprices already-performed work.
- **Retainer** — tied to a taxpayer (optionally scoped to one engagement):
  `initialAmount`, `currentBalance`, optional replenishment threshold,
  deposits[] (date/amount/payment link), draws[] (date/amount/invoice link).
- **Invoice** — sequential `invoiceNumber`, one or more line items drawn
  from flat engagements and/or unbilled time entries, `status`
  (`draft`\|`sent`\|`partially_paid`\|`paid`\|`overdue`\|`void`), and
  derived `amountPaid`/`amountOutstanding` computed from its payments.
- **Payment** — date, amount, method, against one invoice; supports partial
  payments and retainer draws as a payment source.

### The fee-schedule guarantee invariant

The user's own practice is subject to a professional-conduct rule (cited in
conversation as "IRS Publication 23" — unverified; most likely a state
board of accountancy advertising rule, or adjacent to Circular 230 §10.30
solicitation rules; **the exact citation is an open item for the user or
counsel to confirm**, not something this document asserts as settled). The
functional requirement is clear regardless of the exact citation: a
published fee schedule must be honored for a minimum period once published.

The system enforces this mechanically as a pure function contract,
implemented identically (by hand) in all three platforms:

```
canSupersedeFeeSchedule(schedule, now) =
    now >= schedule.publishedAt + schedule.guaranteeDays
```

A `FeeSchedule` cannot be replaced by a new one before this returns true;
the UI blocks the edit rather than merely warning. `guaranteeDays` defaults
to 30 and the UI refuses to set it lower without an explicit, logged
override. Because every `Engagement` records which fee-schedule line item it
was quoted from, a client's committed price stays provably what they were
quoted even after a later schedule supersedes the one they signed under.

## 7. Cloud synchronization

Modeled directly on Saldima's own snapshot-sync design (its
`TECHNICAL-DESIGN.md` §11-12) rather than reinvented: one practitioner per
vault makes the problem much easier than general multi-writer sync.

- Whole-vault snapshots, not event/CRDT sync.
- Each snapshot carries a monotonic revision number; the server rejects an
  upload based on a stale revision rather than merging it.
- A single active-editing lease per vault, with expiration; a second device
  opens read-only until the lease is released.
- Large attachments are individually encrypted, content-addressed objects
  referenced from the case manifest, so editing a task description never
  re-uploads a multi-hundred-megabyte document set.
- No automatic conflict resolution/merge in the initial implementation —
  deferred, same as Saldima defers it. The application tells the user to
  pull the newer revision first.

For the web client specifically, "open the vault" and "pull the latest
snapshot" are the same operation, and "save" and "push a new revision" are
the same operation — there is no separate local vault state to reconcile
against, consistent with §5's "web has no local-first vault."

## 8. Repository layout

```
advocatra/                     # web/cloud, TypeScript
  apps/web/                    # Cloudflare Workers, Hono
  packages/case/                # canonical case schema (pure TS)
  packages/billing/              # canonical billing schema (pure TS)
  packages/crypto/               # Web Crypto key hierarchy (passphrase KDF, wrap/unwrap, HKDF, AEAD envelope)
  packages/vault/                # manifest + snapshot assembly on top of packages/crypto
  packages/sync/                 # revision + lease logic (pure); no Workers/DO wiring yet
  packages/testkit/              # fakes (Clock, IdGenerator, KV, SQL, fetch, email) for every package/app above
  docs/architecture/TECHNICAL-DESIGN.md   # this document

advocatra-ios/                 # native Swift/SwiftUI
  AdvocatraCore/                # pure-Swift mirror of case + billing schema
  AdvocatraVault/                # vault crypto, on-device storage, and the cloud
                                # networking client (login, vault manifest/snapshot) --
                                # no separate AdvocatraSync module; that responsibility
                                # lives here instead
  Advocatra/                    # SwiftUI app
  docs/architecture/TECHNICAL-DESIGN.md   # mirrored copy

advocatra-android/              # native Kotlin/Compose
  core/                          # pure-Kotlin/JVM mirror of case + billing schema
  sync/                          # snapshot sync client (added later)
  app/                           # Compose app
  docs/architecture/TECHNICAL-DESIGN.md   # mirrored copy

advocatra-mcp/                  # local, read-only MCP server (Claude/opencode) over a
                                # decrypted vault snapshot -- a fourth real client of
                                # the cloud API, not just a future port target
advocatra-case-verifier/        # deferred to M3: cross-platform fixture parity
```

## 9. Risks and open questions

- **Fee-schedule-guarantee citation.** "IRS Publication 23" could not be
  verified as an existing IRS publication covering this requirement.
  Confirm the actual source (state board advertising rule? Circular 230?)
  with the user/counsel. The mechanical enforcement in section 6 is correct
  regardless of citation, but the default `guaranteeDays` value and any
  jurisdiction-specific wording in the UI should match the real rule.
- **Argon2id in the browser.** Web Crypto's native KDFs are PBKDF2 and
  HKDF; Argon2id requires a WASM dependency. `packages/vault`'s
  `createVault` uses PBKDF2-SHA256 at 600,000 iterations today — the
  documented fallback, not an invented scheme (same constant Saldima
  ships) — but Argon2id remains preferred if/when an audited WASM
  implementation is vetted (license, audit status) for adoption.
- **iOS/Android/MCP ports of `createVault`/`unlockVaultWithPassphrase`/
  `unlockVaultWithRecoveryCode` don't exist yet.** The web repo
  (`packages/crypto`/`packages/vault`) is the only place the crypto for
  creating or unlocking a vault exists today. The server-side storage half
  is done — `GET`/`PUT /vault/manifest` on the `Vault` DO (opaque,
  session-gated, ported from Saldima's `/app/vault/keys`) — so any client
  can now store/fetch the manifest; what's missing is each client doing
  the local `createVault`/`unlockVaultWith*` sequence itself. Every client
  — the native apps, and any future local MCP server — needs its own
  hand-port of this exact sequence (no shared code, same as the rest of
  this project), not a reinvention of it.
- **StoreKit/Play Billing.** If the native apps ever surface the $20/mo or
  $200/yr hosted plan for purchase *inside* the app, Apple/Google may
  require it be sold through their in-app purchase systems (30% platform
  cut, subscription management constraints). Saldima's own iOS design doc
  flags this exact question as unresolved for its own (different) one-time
  "Supporter" purchase. Decide before the cross-device-sync milestone:
  likely answer is "hosted plan is purchased on the web only via Stripe;
  the apps only authenticate against an existing subscription," mirroring
  Saldima's Android stance ("hosting is bought on the web"), but this is
  not yet a final decision.
- **Zero-knowledge independent review.** Encrypting client-side is
  necessary but not sufficient for a zero-knowledge claim; an independent
  security review is required before accepting real client PII, same
  conclusion reached independently earlier in this project's design
  conversation.
- **No formal cross-platform fixture verification yet.** Until
  `advocatra-case-verifier` exists (M3), schema parity across the three
  platforms is maintained by hand-review, not by an automated check. Treat
  any schema change as incomplete until it has been applied to all three
  repos in the same logical change.
- **Account authentication: resolved, implemented.** Mirrors Saldima's
  actual mechanism exactly — PBKDF2 password hashing (100,000 iterations,
  Cloudflare Workers' WebCrypto hard cap), session cookies, TOTP 2FA,
  per-tenant vanity-subdomain provisioning via KV. See `apps/web/src/auth.ts`,
  `signup.ts`, `provision.ts`, `accounts.ts`, `vault-do.ts`.
- **Stripe product/price setup: done for dev, test mode only.** "Advocatra
  Monthly Subscription" ($20/mo) and "Advocatra Annual Subscription"
  ($200/yr) exist under the same arleyxu financial services Stripe account
  Saldima uses, created by the owner directly in the Stripe dashboard. A
  webhook endpoint for `https://dev.advocatra.com/webhook/stripe` exists
  and its signing secret, plus the Stripe secret key, are set as
  `wrangler secret`s on `advocatra-dev` (never committed). Live-mode
  products/prices and staging/production webhook endpoints are not yet
  created — do that when those environments are actually being stood up,
  not preemptively.
