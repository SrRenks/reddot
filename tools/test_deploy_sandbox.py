#!/usr/bin/env python3
"""Exercise deploy/uninstall against a temporary HOME-like config root."""
import sys
import tempfile
from pathlib import Path

REPO = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(REPO / "installer"))

import deploy


def main():
    with tempfile.TemporaryDirectory() as tmp:
        root = Path(tmp) / "config"
        root.mkdir()
        first = deploy.deploy(config_root=root, apply=True)
        assert (root / "hypr").is_dir()
        assert any(action["action"] in ("deploy", "replace") for action in first)
        assert (root / "hypr" / deploy.MARKER).exists()

        second = deploy.deploy(config_root=root, apply=True)
        assert all(action["action"] in ("replace", "skip") for action in second)

        removed = deploy.uninstall(config_root=root, apply=True)
        assert any(action["action"] == "remove" for action in removed)
        assert not (root / "hypr").exists()
        print("deploy sandbox: deploy, re-deploy and uninstall passed")


if __name__ == "__main__":
    main()
