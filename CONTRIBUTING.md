# Contributing to Advocatra for iPhone

<!-- SPDX-License-Identifier: AGPL-3.0-only -->

Advocatra is licensed under `AGPL-3.0-only`. Outside contributions require the
[Contributor License Agreement](CLA.md), confirmed through the CLA Assistant
check on your pull request. You keep your copyright and grant the project the
rights described there.

## Before you start

- Open or claim an issue. Small, single-purpose changes are much easier to
  review.
- Read [`CLAUDE.md`](CLAUDE.md) for the stack, commands and rules.
- This is a tax-representation case management tool. Never commit real
  taxpayer or client data, even anonymised-looking samples; use synthetic
  fixtures only.

## Test-first

1. Write the failing test and watch it fail for the right reason.
2. Write the smallest change that makes it pass.
3. Refactor with the suite green.

## Local checks

```sh
swift test
```

## Pull requests

- One branch, one small PR, squash merge. Never push to `main`.
- Add the SPDX header to every file you create.
- Never commit secrets, keys, tokens or taxpayer/client data.
- Do not deploy, tag, or upload to TestFlight. The owner approves every
  release.

## Reporting security issues

Do not open a public issue for a vulnerability. Contact the owner privately
via the GitHub account `johnarleyburns`.
