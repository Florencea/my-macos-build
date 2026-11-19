---
trigger: glob
globs: "**/.github/workflows/*.yml, **/.github/workflows/*.yaml, **/.github/actions/**"
description: GitHub Actions CI pinning, concurrency, timeout, and local actionlint invariants.
---

# GitHub Actions CI Rules

- **Exact SemVer Pinning**: Pin all GitHub Actions and reusable workflows to exact SemVer tags (`@vX.Y.Z`); never use floating major or minor tags (`@v1`, `@v7.0`). Check latest tags via `git ls-remote --tags --refs https://github.com/<owner>/<repo>.git`.
- **Concurrency & Timeouts**: Declare top-level `concurrency` (`group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}`) on `push`/`pull_request` workflows and explicit `timeout-minutes: 15` on every job.
- **Architecture-Aware Caching**: Include `${{ runner.os }}-${{ runner.arch }}` in cache keys and set explicit `retention-days` on `upload-artifact`.
- **Local Shift-Left Verification**: Validate modified workflows locally with `actionlint` (`0` errors/warnings) before staging; never embed `actionlint` steps inside remote workflow YAML files.
