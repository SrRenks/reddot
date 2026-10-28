# ADR 0031: Custom profile

- Status: implemented
- Date: 2026-10-28

## Context

Full and Quick were wired, but Custom was still an empty choice. Custom differs
only in the optional-app default: Full preselects all, Custom preselects none.

## Decision

The wizard accepts `3` for Custom. It reuses the Full app list, but an empty
selection means no optional apps; explicit numbers select a subset. The selected
profile is passed as `reddot-plan --profile custom --optional ...`.

`--custom` is forwarded by `install.sh` for non-interactive preselection.

## Verification

The quickstart dry-run and apply/uninstall integration still pass. The custom
selection path uses the same plan filter and optional list already covered by the
plan parity suite.

## Consequences

Quick, Full and Custom profiles are available without Python. Remaining work is
final report parity and real VM validation.
