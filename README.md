# rust-actions

[![Discord](https://img.shields.io/badge/Discord-Join%20us-5865F2?logo=discord&logoColor=white)](https://discord.gg/6qsdhSPE)

Reusable GitHub workflow for releasing agent-ix Rust binaries: build four
native targets, package one archive per target, cut a GitHub Release, and
optionally publish an npm launcher package via
[`agent-ix/nodejs-actions/publish-native-npm`](https://github.com/agent-ix/nodejs-actions).

This is the generic, cross-repo version of the build workflow proven in
`agent-ix/quoin`'s `.github/workflows/native-release.yml`. It has no
knowledge of any one consumer repo — every project-specific detail (binary
name, cargo package, npm package) comes from inputs.

**Never add a workflow to a caller repo that duplicates this one.** If a
caller repo needs to build and release a Rust binary, it calls this
workflow; it does not inline its own copy of the build/package/release
steps.

## Why the workflow looks the way it does

- **Linux builds on `ubuntu-22.04` / `ubuntu-22.04-arm`**, not 24.04. A
  24.04-built binary links glibc 2.39 and fails to start on Ubuntu 22.04 and
  on default WSL, which ships 22.04.
- **Windows packaging uses `7z`**, not `zip`. Git Bash on the Windows runner
  has no `zip` binary; 7-Zip is preinstalled on GitHub's Windows runners.
- **`gh release create` always passes `--repo`.** The `publish` job has no
  checkout of the caller repo (only downloaded artifacts), so `gh` cannot
  infer the repository from a working tree.
- **Every job carries a `timeout-minutes`.** Without one, a hung step blocks
  for GitHub's 6-hour default.
- **The npm publish step is inside `publish-native-npm`** and can wait up to
  15 minutes for a package to become installable after publish.

## Workflow: `.github/workflows/native-release.yml`

`on: workflow_call`. Two jobs: `build` (matrix over four targets) then
`publish` (`needs: build`, only when `publish` is true).

### Inputs

| Name | Required | Default | Description |
|---|---|---|---|
| `tag` | Yes | — | Existing git tag to build, e.g. `v1.2.3`. |
| `binary` | Yes | — | Binary name, e.g. `quoin`. On Windows the file is `<binary>.exe`. |
| `cargo-package` | No | `""` (= `binary`) | Cargo package built with `cargo build -p`. |
| `cargo-dir` | No | `"."` | Directory containing the Cargo workspace/package, relative to the repo root. |
| `pre-build` | No | `""` | Optional bash snippet run as `bash -c "$PRE_BUILD"` before `cargo build`, on every matrix leg including Windows (Git Bash). E.g. `pnpm install --frozen-lockfile` for a crate whose `build.rs` embeds JS-authored fixtures. |
| `setup-pnpm` | No | `false` | Installs pnpm 11.20.0 and Node 22.15.0, then runs `agent-ix/nodejs-actions/setup-npmrc@main` with `REGISTRY_TOKEN`, before `pre-build` runs. Needed when `pre-build` runs `pnpm install` against `@agent-ix`-scoped packages. |
| `npm-package` | No | `""` | When set, also publish to npm via `publish-native-npm`, e.g. `@agent-ix/quoin`. |
| `npm-description` | No | `""` | Description written into the npm launcher `package.json`. Required when `npm-package` is set. |
| `self-update-command` | No | `""` | Subcommand the npm launcher intercepts to print an "update with npm" hint instead of spawning the binary, e.g. `update`. |
| `publish` | No | `false` | When `false`, build, package and smoke every target, but create no GitHub Release and publish nothing to npm. When `true`, also cut the release and, if `npm-package` is set, publish it. |

### Secrets (all optional)

| Name | Used for |
|---|---|
| `REGISTRY_TOKEN` | Authenticates `pnpm install` against `@agent-ix`-scoped GitHub Packages (via `setup-npmrc`, when `setup-pnpm` is true) **and** authenticates private cargo git dependencies, via a `git config --global url.insteadOf` rewrite applied only when this secret is non-empty. |
| `NPM_TOKEN` | npm auth token passed through to `publish-native-npm`. Trusted-publisher packages (the `@agent-ix` public-npm packages) publish tokenlessly via OIDC as long as the caller job grants `id-token: write` — this only matters for a package with no trusted publisher configured yet, e.g. its first publish. |

### Outputs

The workflow declares no `workflow_call` outputs. What it produces:

- A GitHub Release at `tag`, titled `<binary> <tag>`, with release notes and
  four assets: `<binary>-v<version>-<target>.tar.gz` (Linux x86_64/aarch64,
  macOS aarch64) and `<binary>-v<version>-<target>.zip` (Windows x86_64),
  plus `<binary>-update-manifest.json` (schema_version 1) and
  `SHA256SUMS.txt`.
- When `npm-package` is set and `publish` is true, an npm launcher package
  plus one per-platform binary package, published by `publish-native-npm`.
- When `publish` is false, only build artifacts (uploaded as GitHub Actions
  artifacts, one per target) — no release, no npm publish.

### Permissions the caller must grant

A reusable workflow's effective permissions are the intersection of what it
declares and what the calling job grants — this workflow declares
`contents: read` at the top level and elevates to `contents: write,
id-token: write` only inside its own `publish` job, but **the caller's job
must still grant those, or the elevation has nothing to draw from**:

```yaml
permissions:
  contents: write
  id-token: write
```

### Example caller

```yaml
name: Release

on:
  workflow_dispatch:
    inputs:
      tag:
        description: "Existing vX.Y.Z tag to build and release"
        required: true
        type: string
      publish:
        description: "Publish the GitHub Release and npm package. Leave false for a dry run."
        required: false
        type: boolean
        default: false

permissions:
  contents: write
  id-token: write

jobs:
  release:
    if: github.ref == 'refs/heads/main'
    uses: agent-ix/rust-actions/.github/workflows/native-release.yml@main
    with:
      tag: ${{ inputs.tag }}
      binary: example-cli
      npm-package: "@agent-ix/example-cli"
      npm-description: "Example CLI (native binary)."
      self-update-command: update
      publish: ${{ inputs.publish }}
    secrets:
      NPM_TOKEN: ${{ secrets.NPM_TOKEN }}
      REGISTRY_TOKEN: ${{ secrets.REGISTRY_TOKEN }}
```

## Migration

`quoin` and `quire-cli` currently carry their own repo-local build workflows.
They migrate onto this reusable workflow later, under a tracked ticket — this
repo does not vendor or duplicate their release logic in the meantime.

## Lint

```bash
make lint
```

YAML-parses every workflow under `.github/workflows/` with `python3`'s
`yaml.safe_load`, and runs [`actionlint`](https://github.com/rhysd/actionlint)
over them when it's installed on `PATH`.
