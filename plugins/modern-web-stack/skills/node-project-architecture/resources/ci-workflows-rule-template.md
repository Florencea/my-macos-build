---
trigger: glob
globs: ".github/workflows/**"
description: CI workflow verification standards, actionlint requirements, and security guidelines.
---

# CI & GitHub Actions Workflow Standards

Standards for maintaining and updating GitHub Actions workflows.

## 1. Shift-Left Local Verification

- **Strict Requirement**: Whenever `.github/workflows/` files are added or modified, run `npm run agent:lint:ci` (`actionlint`) locally with **0 errors and 0 warnings** before staging (`git add`).
- **Offline-Only Invariant**: `actionlint` is strictly a local check; NEVER embed `actionlint` steps inside remote `.github/workflows/*.yml` files.

---

## 2. GitHub Actions Runner Invariants

- **Exact SemVer Pinning**: Pin every GitHub Action and reusable workflow to an exact stable SemVer tag (`@vX.Y.Z`, never floating `@v1` or `@v7.0`). Verify tags via `git ls-remote --tags --refs https://github.com/<owner>/<repo>.git`.
- **Concurrency Policy**: Declare top-level `concurrency` with `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}` on `push` and `pull_request` workflows.
- **Job Timeout Protection**: Declare an explicit `timeout-minutes: 15` on every job.
- **Architecture-Aware Caching**: Include `${{ runner.os }}-${{ runner.arch }}` in cache keys to isolate runner environments.
- **Explicit Dependency & Browser Setup**: Use `npm ci` (respecting `.npmrc` `ignore-scripts=true`) and install Playwright browsers explicitly via `npm run test:setup`.
- **Artifact Retention**: Configure failure artifact uploads with explicit `retention-days: 7` and `if-no-files-found: ignore`.
- **Node.js Runtime Invariant**: Align workflow Node.js runtime with `package.json` `engines.node` (`Node.js (Active LTS)`).
