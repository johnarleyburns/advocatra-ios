<!-- SPDX-License-Identifier: AGPL-3.0-only -->
# Advocatra for iPhone

The native iOS track of [Advocatra](https://github.com/johnarleyburns/advocatra),
an open-source IRS representation case management tool. See that repo's
[`docs/architecture/TECHNICAL-DESIGN.md`](docs/architecture/TECHNICAL-DESIGN.md)
(mirrored here) for the full design.

## Status

Foundational scaffold only: `AdvocatraCore` is a pure-Swift, hand-ported
mirror of the web repo's canonical case/billing schema, with Swift Testing
suites proving the key invariants (Tax Court requiring `TaxCourtDetails`,
the fee-schedule guarantee window, pricing-type-required-fields). There is
no SwiftUI app target, Xcode project, sync client, or storage layer yet.

## Local development

```sh
swift test
```
