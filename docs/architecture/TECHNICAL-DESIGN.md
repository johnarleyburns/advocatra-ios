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

This is a conceptual layout. The browser implementation uses IndexedDB
stores with the same logical shape; the native implementations use an
on-disk directory (iOS: Application Support; Android: app-private storage).

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

### Storage adapters

| Operation | Browser | iOS/Android |
| --- | --- | --- |
| Create vault | IndexedDB | app-private directory |
| Open vault | browser database | local directory |
| Add document | file upload | filesystem/photo picker |
| Export vault | download archive | save archive |
| Import vault | upload archive | open archive |
| Cloud sync | encrypted upload/download | encrypted upload/download |

### Encryption, every platform

Account authentication (email/password, Stripe subscription) is **always
separate** from vault encryption. The account password never becomes, or
derives, the encryption key.

Key hierarchy:

- A random **vault master key**.
- Separate derived keys for the record index and for document objects
  (HKDF from the master key, distinct `info` strings per purpose).
- Per-object random nonces; AES-256-GCM (authenticated encryption)
  everywhere.
- The vault master key itself is wrapped by a key-encryption key (KEK)
  derived from the user's passphrase via Argon2id where available, or
  PBKDF2 (high iteration count) via native Web Crypto where Argon2id isn't
  practically available — flagged as an open risk in section 9; do not
  invent a custom KDF.
- Versioned encryption metadata on every object, so the format can evolve
  without breaking old vaults.

This applies uniformly: encrypted-at-rest on iOS/Android (protected by a
Keychain/Keystore-held key, unlocked by device passcode/biometric or an
app passphrase) — a deliberate departure from Saldima, whose iOS/Android
local `.gnucash` file is unencrypted by Saldima's own explicit design
decision. Advocatra cannot make that same call given the sensitivity of the
data it stores.

The recovery process is a product decision that must be nailed down before
accepting real client data: losing the encryption key must not let
Advocatra's own operator decrypt the vault (that is the whole point of the
zero-knowledge claim), which means key loss is also, by construction,
unrecoverable unless the user set up an explicit recovery mechanism they
control (e.g., a printed recovery code) ahead of time.

## 6. Billing, engagements and fee schedules

A tax practice needs to know what it promised, what it's owed, and what's
been paid — this is as core to the product as the case file itself, and it
lives in the same encrypted vault (billing records for a named client are
themselves confidential).

### Objects

- **FeeSchedule** — the firm's published rate card, versioned.
  `effectiveDate`, `publishedAt`, `guaranteeDays` (default 30 — see the
  invariant below), line items: `{ serviceCode, label, pricingType:
  "flat"|"hourly", amount }` (e.g. `1040-W2` flat $80, `1040-SCHC-INVEST`
  flat $500, `HOURLY-STANDARD` hourly rate).
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

## 8. Repository layout

```
advocatra/                     # web/cloud, TypeScript
  apps/web/                    # Cloudflare Workers, Hono
  packages/case/                # canonical case schema (pure TS)
  packages/billing/              # canonical billing schema (pure TS)
  packages/crypto/               # Web Crypto wrappers (added when storage lands)
  packages/sync/                 # snapshot sync client (added later)
  docs/architecture/TECHNICAL-DESIGN.md   # this document

advocatra-ios/                 # native Swift/SwiftUI
  AdvocatraCore/                # pure-Swift mirror of case + billing schema
  AdvocatraSync/                # snapshot sync client (added later)
  Advocatra/                    # SwiftUI app
  docs/architecture/TECHNICAL-DESIGN.md   # mirrored copy

advocatra-android/              # native Kotlin/Compose
  core/                          # pure-Kotlin/JVM mirror of case + billing schema
  sync/                          # snapshot sync client (added later)
  app/                           # Compose app
  docs/architecture/TECHNICAL-DESIGN.md   # mirrored copy

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
  HKDF; Argon2id requires a WASM dependency. Decide and vet that dependency
  (license, audit status) before the encryption milestone, rather than
  defaulting to a weaker PBKDF2-only scheme silently.
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
