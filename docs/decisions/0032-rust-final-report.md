# ADR 0032: Rust final report

- Status: implemented in the quickstart entry point
- Date: 2026-10-28

## Context

The quickstart ended with a technical completion line. The Python installer ends
with a human closing report: dry-run/real title, next login steps and init notes.

## Decision

`reddot-report --final` appends:

- `Dry run complete` or `reddot is in`;
- login, Hyprland, launcher and wallpaper next steps;
- the non-systemd service note;
- the dry-run log hint.

`reddot-install` calls it with the plan, family, init and dry-run state.

## Verification

The quickstart dry-run integration still passes and now includes the closing
lines; the isolated apply/uninstall run also completes.

## Consequences

The quickstart path has a closing report. Remaining gaps are VM validation and
removal of the Python parity harness.
