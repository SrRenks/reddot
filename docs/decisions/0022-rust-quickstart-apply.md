# ADR 0022: quickstart fallbacks and apply

- Status: quickstart apply implemented; interactive wizard and install.sh handoff remain
- Date: 2026-10-28

## Context

The quickstart dry-run proved the core integration. The next step is to execute
fallback steps and the deploy/post phases for a real quickstart run.

## Decision

The entry point now:

- parses fallback rows from the plan and asks `reddot-fallbacks` for their steps;
- passes the combined steps to `reddot-run`;
- with `--apply`, runs deploy, neutralize and post-install for real;
- calls `reddot-post baseline` with the deployed update engine;
- keeps `--dry-run` as the default-safe path.

The plan now carries the optional flatpak id in fallback rows so the fallback
binary can build the right step list.

## Verification

- `tools/test-reddot-install-rust.sh` still exercises the full dry-run bundle.
- A `--quickstart --no-deps --apply` run in an isolated HOME/config root completed
  without touching the live config or package database.
- The fallback dry-run shows the rishot curl step for the detected plan.

## Consequences

Quickstart can now install configs and run package/fallback steps. The interactive
wizard, full real-install VM matrix, install.sh switch and Python removal remain.
