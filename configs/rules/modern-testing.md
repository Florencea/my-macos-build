---
trigger: glob
globs: "test/**, **/*.test.*, **/*.spec.*, vitest.config.*"
description: Testing standards for Vitest Browser projects, headless Playwright execution, token-efficient output, and three-tier gatekeeper hierarchy.
---

# Modern Testing Guidelines & Gatekeeper Invariants

## 1. Unified Vitest Browser Projects (No Standalone Playwright Config)

- **Native Vitest Browser Mode**: Write component and E2E browser tests directly using `vite-plus/test` and `vite-plus/test/browser-playwright`.
- **Eliminate Duplicate Toolchains**: Do NOT introduce standalone `playwright.config.ts` or standalone dev/preview servers just for testing. Configure projects directly in `vite.config.ts`.
- **Headless Execution**: Always configure browser instances with `headless: true` and provider `playwright()` with `chromium`.

---

## 2. Agent-Friendly Non-Interactive Output

When running test suites as an agent, ALWAYS use token-efficient structured flags to eliminate animated terminal spinners and raw ANSI escapes:

- Preferred: `vp test run --project <name> --reporter=tap-flat --no-color`
- Machine JSON: `vp test run --json`
- Single File: `vp test run <file> --reporter=tap-flat --no-color`

---

## 3. Three-Tier Gatekeeper Architecture

Structure and execute verification scripts according to the three-tier hierarchy:

1. **Tier 1 (Inner Loop - `agent:verify:inner`)**:
   - Runs `vpr typecheck` + `vp lint` + `vpr lint:tailwind`.
   - Ultra-fast feedback loop (< 2s) during active code editing.
2. **Tier 2 (Unit Verification - `agent:verify:unit`)**:
   - Runs `agent:verify:inner` + `agent:test:unit`.
   - Validates unit behavior without incurring heavy build/bundle overhead.
3. **Tier 3 (Gatekeeper - `agent:verify:gate` or `vpr verify`)**:
   - Runs comprehensive gate: `unit` + `build` + `e2e` + `knip` (deadcode).
   - Mandatory before completing substantial features or refactoring.
