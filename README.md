<!-- SPDX-License-Identifier: AGPL-3.0-only -->
# Advocatra for iPhone

The native iOS track of [Advocatra](https://github.com/johnarleyburns/advocatra),
an open-source IRS representation case management tool. See that repo's
[`docs/architecture/TECHNICAL-DESIGN.md`](docs/architecture/TECHNICAL-DESIGN.md)
(mirrored here) for the full design.

## Status

`AdvocatraCore` is a pure-Swift, hand-ported mirror of the web repo's
canonical case/billing schema, with Swift Testing suites proving the key
invariants (Tax Court requiring `TaxCourtDetails`, the fee-schedule
guarantee window, pricing-type-required-fields). CI/CD mirrors
`saldima-ios`: Linux portable-logic tests, an unsigned Apple compile job,
and an owner-merge-gated TestFlight upload (currently no-ops — some
signing secrets aren't configured yet). The app target is a placeholder
shell, not real case-management UI. There is no sync client or on-device
storage layer yet.

## Local development

```sh
xcodegen generate   # regenerate Advocatra.xcodeproj from project.yml
swift test
```
