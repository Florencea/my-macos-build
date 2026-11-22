---
trigger: glob
globs: "**/.github/workflows/*.yml, **/.github/workflows/*.yaml, **/.github/actions/**"
description: Cross-language GitHub Actions CI pinning, permissions, concurrency, timeout, and local actionlint invariants.
---

# GitHub Actions CI Rules

- **Exact SemVer Pinning**: Pin all GitHub Actions and reusable workflows to exact stable SemVer tags (`@vX.Y.Z`); never use floating major or minor tags (`@v1`, `@v7.0`). Verify latest tags via `git ls-remote --tags --refs https://github.com/<owner>/<repo>.git`.
- **Least Privilege, Concurrency & Timeouts**: Declare top-level `permissions: contents: read`, top-level `concurrency` (`group: ${{ github.workflow }}-${{ github.ref }}`, `cancel-in-progress: ${{ github.ref != 'refs/heads/main' }}`) on `push`/`pull_request` workflows, and explicit `timeout-minutes: 15` on every job.
- **Architecture-Aware Caching & Artifacts**: Include `${{ runner.os }}-${{ runner.arch }}` in custom cache keys and set explicit `retention-days` (e.g. `7`) with `if-no-files-found: ignore` on `upload-artifact`.
- **Standard Toolchain Gates**:
  - **Go**: Use `actions/setup-go` (`go-version-file: go.mod`, `cache: true`), run `gofmt -l .`, `go vet ./...`, `go test -race -count=1 ./...`, `golang/govulncheck-action`, and `CGO_ENABLED=0 go build`.
  - **Node.js**: Use `actions/setup-node` (`cache: npm`), `npm ci`, explicit browser install (`npm run test:setup`) when E2E tests are present, and shared `npm run` verification commands.
- **Local Shift-Left Verification**: Validate modified workflows locally with `actionlint` (`0` errors/warnings) before staging; never embed `actionlint` steps inside remote workflow YAML files.
