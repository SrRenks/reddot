# Validation checklist

Run from the checkout unless noted.

## Static and logic

- [ ] `sh tools/check-static.sh`
- [ ] `sh tools/check.sh` (deployed tree; needs a session)
- [ ] `sh tools/check-hypr-api.sh`
- [ ] `node tools/check-doc-links.mjs`

## Installer

- [ ] `sh tools/test-reddot-install-rust.sh`
- [ ] `sh tools/test-reddot-install-matrix.sh`
- [ ] `sh tools/reddot-run` tests included in `check-static.sh`

## Runtime

- [ ] `sh tools/smoke-surfaces.sh` (running pill)
- [ ] `reddot status`
- [ ] `reddot update` shows no unapplied conflicts
- [ ] lock on every physical output, then unlock normally

## Cleanup

- [ ] no tracked `.py` files: `git ls-files '*.py'`
- [ ] `git status` clean after the run
- [ ] assets and docs links resolve
