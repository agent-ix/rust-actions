# rust-actions

Reusable GitHub workflow for releasing agent-ix Rust binaries: build native
targets, package archives, cut a GitHub Release, and optionally publish an
npm launcher package via `agent-ix/nodejs-actions/publish-native-npm`. No
local build or deploy of its own — this repo only ships workflow YAML.

**Never add a workflow to a caller repo that duplicates this one.** If a
caller repo needs to build and release a Rust binary the way this workflow
does, it calls `agent-ix/rust-actions/.github/workflows/native-release.yml`;
it does not inline its own copy of the build/package/release steps.

## Lessons learned, and why each rule exists

- **Linux must build on `ubuntu-22.04` / `ubuntu-22.04-arm`.** Built on
  24.04, the binary needs glibc 2.39 and fails on Ubuntu 22.04 and on
  default WSL.
- **Windows packaging must use `7z`**, because Git Bash on the Windows
  runner has no `zip`.
- **`gh release create` must pass `--repo`**, because the publish job has no
  checkout.
- **Every job needs a `timeout-minutes`**, so a hung step doesn't block for
  GitHub's 6-hour default.
- **The npm verify step is inside `publish-native-npm`** and waits up to 15
  minutes for a just-published version to become installable.

## Rules for this repo

- Pin third-party actions by commit SHA (a trailing `# vX.Y.Z` comment names
  the tag, but the ref that runs is the SHA).
- Never interpolate workflow inputs directly into a `run:` script; always
  pass them through `env:` first.
- Every `run:` script uses `set -euo pipefail`.
- Do not vendor or copy another repo's release logic into this one, and do
  not vendor this workflow's logic back out into a caller repo — see the
  rule above.
