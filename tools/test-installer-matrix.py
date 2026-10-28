#!/usr/bin/env python3
"""Exercise installer planning across supported families without installing."""
import sys
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "installer"))

import distro


FAMILIES = ["arch", "debian", "fedora", "suse", "gentoo"]
ACTIONS = {"native", "fallback", "skip"}


def main():
    manifest = distro.load_manifest()
    assert manifest["families"] == FAMILIES
    unknown = {p.get("fallback") for p in manifest["packages"] if p.get("fallback")} - set(manifest["fallbacks"])
    assert not unknown, f"unknown fallbacks: {sorted(unknown)}"

    for family in FAMILIES:
        rows = distro.plan(manifest, family, groups=("core",))
        assert rows, f"{family}: empty core plan"
        for row in rows:
            assert row["action"] in ACTIONS, f"{family}: bad action {row}"
            if row["action"] == "fallback":
                assert row["target"] in manifest["fallbacks"], f"{family}: bad fallback {row}"
            if row["action"] == "native":
                assert row["target"], f"{family}: native row without a name"

    for package in manifest["packages"]:
        for family in FAMILIES:
            action, target = distro.resolve(package, family)
            assert action in ACTIONS, f"{package['id']} on {family}: {action}"
            assert action != "native" or target, f"{package['id']} on {family}: empty native target"

    print("installer matrix: 5 families, core plans and fallback references passed")


if __name__ == "__main__":
    main()
