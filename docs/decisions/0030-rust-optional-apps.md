# ADR 0030: optional app picker

- Status: implemented; custom profile still maps to the Full picker
- Date: 2026-10-28

## Context

The Rust wizard could choose Quick or Full but Full always installed every
optional app. The Python flow lets the user deselect entries.

## Decision

`reddot-plan --list-full` prints the full-group ids. In interactive Full, the
wizard lists `1=id, 2=id, ...` and accepts a comma-separated selection; an empty
answer keeps all. The selection is passed to `reddot-plan --optional`.

`--full` non-interactive keeps the all-apps behavior.

## Verification

- The five-family plan parity and quickstart integration still pass.
- The picker output was checked against the manifest's full group.

## Consequences

Optional apps can now be subsetted without Python. Custom profile selection and
VM validation remain.

Note: the `--full` flag and the interactive picker share the same plan path, so
there is no second selection model to drift.
