---
trigger: glob
globs: ".github/workflows/**"
description: CI workflow verification standards, actionlint requirements, and security guidelines.
---

# CI & GitHub Actions Workflow Standards

Standards for maintaining and updating GitHub Actions workflows.

## 1. Centralized CI Toolchain (`vp-actions`)

- **Standard Web & Fullstack Workflows**:
  - Consume shared Reusable Workflows from `Florencea/vp-actions/.github/workflows/vp-web-ci.yml` (`ubuntu-24.04`) pinned to an exact SemVer tag.
  - Pass custom pre-test commands via `pre-test-command` (e.g. `vp run db:seed`).
- **Electron & Specialized Workflows**:
  - Electron desktop applications consume `Florencea/vp-actions/.github/workflows/vp-electron-ci.yml` (Linux gatekeeper plus macOS and Windows packaging matrix).
  - Custom pipelines consume modular Composite Actions `Florencea/vp-actions/actions/setup-vp-env` (Node.js setup, Vite+, dependencies, Vite Task Cache) and `Florencea/vp-actions/actions/setup-playwright` (Chromium + system deps).

## 2. Shift-Left Local Verification

- **Strict Requirement**: Whenever `.github/workflows/` files are added or modified, run `vpr agent:lint:ci` (`actionlint`) locally with **0 errors and 0 warnings** before staging (`git add`).
- **Offline-Only Invariant**: `actionlint` is strictly a local check; NEVER embed `actionlint` steps inside remote `.github/workflows/*.yml` files.

## 3. GitHub Actions Runner Invariants

- **Exact SemVer Pinning**: Pin every GitHub Action and reusable workflow to an exact stable SemVer tag (`@vX.Y.Z`, never floating `@v1` or `@v7.0`). Verify and upgrade tags via `up` or `git ls-remote --tags`.
- **Concurrency Policy**: Declare top-level `concurrency` with `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}` on `push` and `pull_request` workflows.
- **Job Timeout Protection**: Declare an explicit `timeout-minutes: 15` on every job.
- **Architecture-Aware Caching**: Include `${{ runner.os }}-${{ runner.arch }}` in cache keys to isolate runner environments.
- **Artifact Retention**: Configure failure artifact uploads with explicit `retention-days: 7` and `if-no-files-found: ignore`.
- **Node.js Runtime Invariant**: Align workflow Node.js runtime with `package.json` `engines.node` (`Node.js (Active LTS)`).
