# ADR 0020: crate-free build bundle

- Status: build step implemented; entry point not connected yet
- Date: 2026-10-28

## Context

The installer migration now has fourteen small Rust binaries. They cannot be
tested as a system until one command can build the complete set without Cargo.

## Decision

`tools/build-rust.sh` compiles every helper with `rustc --edition=2021 -O` into a
target directory, defaulting to `~/.local/bin`. It fails loud on a missing source
or toolchain and lists each installed binary.

The build is deliberately crate-free: the target machines only need `rustc`, not
Cargo or a registry cache.

## Verification

The script built all fourteen binaries into a temporary directory during this
phase. `check-static.sh` continues to build each source individually; the bundle
is the integration prerequisite for the Rust installer entry point.

## Consequences

The Rust installer can now assume a single binary directory. Remaining work is
the entry point, wizard wiring, closing report and install.sh handoff.
