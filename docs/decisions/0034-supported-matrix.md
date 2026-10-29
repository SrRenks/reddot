# ADR 0034: supported binary matrix

- Status: accepted
- Date: 2026-10-29

## Context

Real VM validation passed on Arch, Debian 13, Fedora 44 and openSUSE Tumbleweed.
Leap 15.6 has no OBS target for the Hyprland set, and Gentoo requires a source
build that was not part of the verified binary matrix.

## Decision

The supported installer matrix is:

```text
Arch (rolling)
Debian 13+
Fedora 44+
openSUSE Tumbleweed
```

`reddot-install` rejects Leap 15.6, Gentoo, Fedora <44 and Debian <13 with an
explicit message before planning. The package/fallback code for other families
remains for parity tests and future work, but is not advertised.

## Verification

- real VMs: Arch, Debian 13, Fedora 44, Tumbleweed;
- `tools/test-reddot-install-matrix.sh` now covers the four supported families
  and asserts Gentoo is rejected;
- CI static suite.

## Consequences

The product no longer claims source-only/Legacy distros. Re-adding Leap or
Gentoo requires a source-build design and VM validation.
