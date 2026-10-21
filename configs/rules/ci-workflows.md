---
trigger: glob
globs: ".github/workflows/**/*.yml", ".github/workflows/**/*.yaml"
description: Standards for GitHub Actions CI workflows, Vite+ caching, and mandatory local actionlint shift-left verification.
---

# GitHub Actions CI & Workflow Rules

## 1. Local Shift-Left Verification Mandate (`actionlint`)

- **Mandatory Local Linting**: Whenever `.github/workflows/` files are created or modified, agents MUST run `actionlint` locally before staging (`git add`).
- **Zero Errors / Zero Warnings Invariant**: Workflows MUST pass `actionlint` with **0 errors and 0 warnings**.
- **Offline Guardrail Invariant**: `actionlint` is strictly a local pre-commit guardrail. NEVER embed `actionlint` steps or jobs into remote GitHub Actions YAML workflow files.

---

## 2. Standard Vite+ CI Setup & Caching Pipeline

- **Vite+ Action**: Use `voidzero-dev/setup-vp@v1` with dynamic Node resolution from `package.json`:
  ```yaml
  - name: Setup Vite+
    uses: voidzero-dev/setup-vp@v1
    with:
      node-version-file: package.json
      cache: true
  ```
- **Task Runner Caching**:
  - Always cache `node_modules/.vite/task-cache` in GitHub Actions.
  - Allows unmodified steps (linting, typechecking, building, tests) to replay instantly.
- **Playwright Browser Caching**:
  - In workflows running browser/E2E tests, cache Playwright browser binaries:
    `path: ~/.cache/ms-playwright`
    `key: ${{ runner.os }}-playwright-${{ hashFiles('**/pnpm-lock.yaml') }}`

---

## 3. Deterministic Gatekeeper Pipeline

In continuous integration, execute verification tasks in strict topological order:

1. `vp install`
2. `vpr typecheck`
3. `vp check` (Oxlint & Oxfmt)
4. `vpr agent:test:unit`
5. `vp build`
6. `vpr agent:test:e2e` (if browser tests exist)
